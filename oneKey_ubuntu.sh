#!/bin/bash
# Misc Info
catBanner="---------------------------------------------------"
catBanner=$(echo "$catBanner" | sed 's/------/------ /g')
beautifyGap1="->  "
beautifyGap2="    "
beautifyGap3="♣   "
userNotation="@@@@"
mainWd=$(cd $(dirname $0); pwd)
makeJobs=8
commInstdir=/opt
downloadPath=$mainWd/downloads
loggingPath=$mainWd/logs
summaryTxt=$mainWd/summary.txt
systemSrcRoot=/opt/src
# Universal Ctags Info
uCtagsInstDir=$commInstdir/uctags
# Jdk Info - via apt install
jdkSystemInstalledVersion=openjdk-11-jdk
jdkInstDir=/usr/lib/jvm/java-11-openjdk-amd64
javaInstDir=$jdkInstDir
javaPath=$javaInstDir/bin/java
JAVA_HOME=$javaInstDir
# Tomcat Info
tomcatVersion=10.1.13
TOMCAT_HOME=$commInstdir/tomcat
CATALINA_HOME=$TOMCAT_HOME
tomcatInstDir=$TOMCAT_HOME
tomcatUser=tomcat
tomcatGrp=tomcat
setEnvFileName=setenv.sh
setEnvFilePath=$CATALINA_HOME/bin/$setEnvFileName
catalinaShellPath=$tomcatInstDir/bin/catalina.sh
catalinaPIDFile=$tomcatInstDir/temp/tomcat.pid
catalinaGetVerCmd=$tomcatInstDir/bin/version.sh
defaltListenPort=8080
newListenPort=8080
# serverXmlPath=${tomcatInstDir}/conf/server.xml
# srvXmlTemplate=$mainWd/template/server.xml
# OpenGrok Info
openGrokVersion=1.12.12
openGrokInstDir=$commInstdir/opengrok
openGrokTarName=opengrok-$openGrokVersion.tar.gz
openGrokUntarDir=opengrok-$openGrokVersion
openGrokPath=$downloadPath/$openGrokUntarDir
openGrokInstanceBase=$openGrokInstDir
openGrokSrcRoot=$openGrokInstanceBase/src
# OpenGrok Indexer Info
indexerFileName=call_indexer.sh
indexerFilePath=$mainWd/$indexerFileName
indexerLinkTarget=/bin/callIndexer

logo() {
    cat << "_EOF"
  ___  _ __   ___ _ __   __ _ _ __ ___ | | __
 / _ \| '_ \ / _ \ '_ \ / _` | '__/ _ \| |/ /
| (_) | |_) |  __/ | | | (_| | | | (_) |   <
 \___/| .__/ \___|_| |_|\__, |_|  \___/|_|\_\
      |_|               |___/

_EOF
}

preInstallForUbuntu() {
    cat << _EOF
$catBanner
Pre Install Tools for Ubuntu
_EOF

sudo apt-get update
sudo apt-get install -y \
        pkg-config libevent-dev build-essential cmake \
        automake curl autoconf libtool python3 net-tools
}

installuCtags() {
    cat << _EOF
$catBanner
Installing Universal Ctags
_EOF
    # Check if the 'ctags' command is available
    if command -v ctags &> /dev/null; then
        # Check if 'ctags' is Universal Ctags
        if ctags --version | grep -i -q 'universal'; then
            uCtagsBinPath=`which ctags`
            echo "$userNotation Universal Ctags is already installed at: $uCtagsBinPath"
            $uCtagsBinPath --version
            return
        else
            echo "$userNotation ctags is already installed, but it is not Universal Ctags."
            sudo apt-get remove exuberant-ctags -y
        fi
    fi

    if [[ ! -d $uCtagsInstDir ]]; then
        sudo mkdir -p $uCtagsInstDir
    fi

    cd $downloadPath
    local clonedName=ctags
    if [[ -d "$clonedName" ]]; then
        echo "$userNotation Directory $clonedName already exist. Skipping git clone."
    else
        git clone https://github.com/universal-ctags/ctags
        if [[ $? != 0 ]]; then
            echo "$userNotation git clone error, quitting now"
            exit 255
        fi
    fi

    cd $clonedName
    # pull the latest code
    git pull
    ./autogen.sh
    ./configure --prefix=$uCtagsInstDir
    make -j$makeJobs
    if [[ $? != 0 ]]; then
        echo [Error]: make error, quitting now
        exit 255
    fi

    sudo make install
    if [[ $? != 0 ]]; then
        echo [Error]: make install error, quitting now
        exit 255
    fi

    uCtagsBinPath=$uCtagsInstDir/bin/ctags
    # create a soft link to /bin/ctags
    sudo ln -sf $uCtagsBinPath /bin/ctags

    cat << _EOF
$catBanner
Ctags Path = /bin/bash -> $uCtagsBinPath
$($uCtagsBinPath --version)
_EOF
}

installJdk() {
    cat << _EOF
$catBanner
Installing JDK
_EOF
    if [[ -x $javaPath ]]; then
        echo "$userNotation JDK is already installed at: $javaInstDir"
        $javaPath --version
        return
    fi
    sudo apt-get install $jdkSystemInstalledVersion -y

    cat << _EOF
$catBanner
Java Package Install Path = $javaInstDir
Java Path = $javaPath
$($javaPath -version)
_EOF
}

installTomcat() {
    cat << _EOF
$catBanner
Installing Tomcat 10
_EOF
    if [[ -x $catalinaGetVerCmd ]]; then
        echo "$userNotation Tomcat is already installed at: $tomcatInstDir"
        tomcatVerContext="$($catalinaGetVerCmd)"
        tomcatVersion=$(echo "$tomcatVerContext" | awk -F' ' '/Server number:/ {print $NF}')
        echo "$tomcatVerContext"
        echo "Tomcat Version = $tomcatVersion"
        return
    fi

    # Tomcat 10 binary in the official website always changes to the latest version
    # Define the baseUrl for Apache Tomcat 10 releases
    baseUrl="https://dlcdn.apache.org/tomcat/tomcat-10"

    # Fetch the HTML page containing the available versions
    htmlPage=$(curl -s "$baseUrl/")

    # Extract and print the latest version number from the HTML content
    # <a href="v10.1.13/">v10.1.13/</a>
    latestVersion=$(echo "$htmlPage" | grep -oP 'v\d+\.\d+\.\d+' | head -n 1)
    # v10.1.13 => 10.1.13
    tomcatVersion=$(echo "$latestVersion" | grep -oP '\d+\.\d+\.\d+')
    tomcatFullName=apache-tomcat-$tomcatVersion
    tomcatTarName=$tomcatFullName.tar.gz

    if [ -n "$latestVersion" ]; then
        # Construct the URL for the latest Tomcat 10 release binary
        tomcatUrl="$baseUrl/$latestVersion/bin/$tomcatTarName"

        cd $downloadPath
        # Download the latest Tomcat 10 release
        if [[ -f "$tomcatTarName" ]]; then
            echo "$userNotation File $tomcatTarName already exist. Skipping download."
        else
            wget "$tomcatUrl"
        fi
    else
        echo "$userNotation Failed to retrieve the latest Apache Tomcat version."
        exit 1
    fi

    # untar into /opt/tomcat and strip one level directory
    if [ ! -d "$tomcatInstDir" ] || [ -z "$(ls -A "$tomcatInstDir" 2>/dev/null)" ]; then
        if [[ ! -d $tomcatInstDir ]]; then
            sudo mkdir -p $tomcatInstDir
        fi
        sudo tar -zxv -f $tomcatTarName --strip-components=1 -C $tomcatInstDir
        if [[ $? != 0 ]]; then
            echo [Error]: untar tomcat package error, quitting now
            exit
        fi
    else
        echo "$userNotation Directory $tomcatInstDir already exist and is not empty. Skipping untar"
    fi

    # change owner:group of TOMCAT_HOME
    tomcatOwner=`ls -ld $tomcatInstDir | awk '{print $3}'`
    if [[ "$tomcatOwner" == "$tomcatUser" ]]; then
        echo "$userNotation Tomcat owner is already $tomcatUser, skipping chown"
    else
        sudo chown -R $tomcatUser:$tomcatGrp $tomcatInstDir
    fi

    local deployCheckPoint=$tomcatInstDir/webapps/
    if [ "$(stat -c %a $deployCheckPoint)" -eq 755 ]; then
        echo "$userNotation Directory mod is already 755, skipping chmod"
    else
        sudo chmod -R 755 $tomcatInstDir
    fi

    # clear the temp dir in tomcat
    sudo rm -rf $tomcatInstDir/temp/*

    cat << _EOF
$catBanner
Tomcat Version Name = $tomcatFullName
Tomcat Install Path = $tomcatInstDir
_EOF
}

installOpenGrok() {
    cat << _EOF
$catBanner
Installing OpenGrok v$openGrokVersion
_EOF
    local downBaseUrl=https://github.com/oracle/opengrok/releases/download/
    downloadUrl=$downBaseUrl/$openGrokVersion/$openGrokTarName

    cd $downloadPath
    # check if already has tar ball downloaded
    if [[ -f $openGrokTarName ]]; then
        echo "$userNotation File $openGrokTarName already exist. Skipping download."
    else
        wget --no-cookies \
             --no-check-certificate \
             --header "Cookie: oraclelicense=accept-securebackup-cookie" \
             "$downloadUrl" \
             -O $openGrokTarName
        # check if wget returns successfully
        if [[ $? != 0 ]]; then
            echo "$userNotation wget $downloadUrl failed, quitting now"
            exit 1
        fi
    fi

    if [[ ! -d $openGrokUntarDir ]]; then
        tar -zxvf $openGrokTarName
    else
        echo "$userNotation Directory $openGrokUntarDir already exist. Skipping untar."
    fi

    # Info about OpenGrok Web Application
    local warFileName=source.war
    warFilePath=$openGrokUntarDir/lib/$warFileName
    cd $openGrokUntarDir

    # If user does not use default OPENGROK_INSTANCE_BASE then attempt to
    # extract WEB-INF/web.xml from source.war using jar or zip utility, update
    # the hardcoded values and then update source.war with the new
    # WEB-INF/web.xml.
    if [[ "$openGrokInstanceBase" != "/var/opengrok" ]]; then
        cd lib
        if [[ ! -f $warFileName ]]; then
            echo "$userNotation File $warFileName does not exist, quitting now"
            exit 1
        fi
        # Extract and overwrite the WEB-INF/web.xml file from source.war archive.
        unzip -o $warFileName WEB-INF/web.xml

        # Change the hardcoded values in WEB-INF/web.xml
        cd WEB-INF
        local webXmlName=web.xml
        local changeFrom=/var/opengrok/etc/configuration.xml
        local changeTo=$openGrokInstanceBase/etc/configuration.xml
        if grep -q "$changeTo" "$webXmlName"; then
            echo "$userNotation WEB-INF/web.xml already updated, skipping sed and zip -u"
        else
            # update web.xml
            sed -i -e 's:'"$changeFrom"':'"$changeTo"':g' "$webXmlName"
            cd ..
            echo "$userNotation Updating source.war with new WEB-INF/web.xml"
            zip -u source.war WEB-INF/web.xml &>/dev/null
            if [[ $? != 0 ]]; then
                echo "$userNotation zip -u source.war WEB-INF/web.xml failed, quitting now"
                exit 1
            fi
        fi
    fi

    # copy source.war to tomcat webapps
    tomcatWebAppsDir=$tomcatInstDir/webapps
    cd $downloadPath
    sudo -u $tomcatUser cp -f $warFilePath $tomcatWebAppsDir
    if [[ $? != 0 ]]; then
        echo "$userNotation copy $warPath to $tomcatWebAppsDir failed, quitting now"
        exit 2
    fi

    # fix one warning
    cp -f $downloadPath/$openGrokUntarDir/doc/logging.properties \
               ${openGrokInstanceBase}/etc
}

makeIndexer() {
    cat << _EOF
$catBanner
Making Indexer: $indexerFileName
_EOF
    local loggingPropertyFile=$openGrokInstanceBase/etc/logging.properties
    javaIndexerCommand=$(echo $javaPath \
        -Djava.util.logging.config.file=$loggingPropertyFile \
        -jar $openGrokPath/lib/opengrok.jar \
        -c $uCtagsBinPath \
        -s $openGrokSrcRoot \
        -d $openGrokInstanceBase/data -H -P -S -G \
        -W $openGrokInstanceBase/etc/configuration.xml)

    # The indexer will generate opengrok0.0.log at the same directory
    # But I'd like it to generate log file at $loggingPath
    if [[ ! -d $loggingPath ]]; then
        mkdir -p $loggingPath
    fi

    cat << _EOF > $indexerFilePath
#/bin/bash
# Run Tomcat service as user tomcat
tomcatUser=$tomcatUser
tomcatGrp=$tomcatGrp
catalinaShellPath=$catalinaShellPath
tomcatiListenPort=$newListenPort
opengrokLogPath="$loggingPath"
# tomcatLogPath="$tomcatInstDir/logs"
javaIndexerCommand="$javaIndexerCommand"
# Flags
fUpdateIndex=false
fRestartTomcat=false
fStartTomcat=false
fStopTomcat=false
# User notation
userNotation=$userNotation
scriptName=\$(basename \$0)
workingDir=\$(cd \$(dirname \$0); pwd)

usage() {
    cat << __EOF
Usage: \$scriptName [-hursS]
Options:
    -h: Print this help message
    -u: Update index and restart Tomcat
    -r: Restart Tomcat only
    -s: Start Tomcat only
    -S: Stop Tomcat only

Example:
    \$scriptName -u
    \$scriptName -r
    \$scriptName -s
    \$scriptName -S

__EOF
    exit 1
}

[ \$# -eq 0 ] && usage
# Parse the options
while getopts "hrusS" opt
do
    case \$opt in
        h)
            usage
            exit 0
            ;;
        s)
            fStartTomcat=true
            break
            ;;
        S)
            fStopTomcat=true
            break
            ;;
        r)
            fRestartTomcat=true
            break
            ;;
        u)
            fUpdateIndex=true
            break
            ;;
        ?)
            echo "\$userNotation Invalid option: -\$OPTARG" 2>&1
            exit 1
            ;;
    esac
done

# Shift to process non-option arguments. New \$1, \$2, ..., \$@
shift \$((OPTIND - 1))
if [ \$# -gt 0 ]; then
    echo "\$userNotation Illegal non-option arguments: \$@"
    exit 1
fi

# Variables
stopWaitTime=1
startWaitTime=2
loopMax=2

forceStopTomcat() {
    local loopCnt=0
    while true; do
        sudo lsof -i :\$tomcatiListenPort
        if [[ \$? == 0 ]]; then
            # Check the loop limit
            if [[ \$loopCnt -ge \$loopMax ]]; then
                echo "\$userNotation Max loop reached, force stop tomcat failed."
                break
            fi
            echo "\$userNotation Force stop tomcat ..."
            sudo \$catalinaShellPath stop -force
            sleep \$stopWaitTime
        else
            if [[ \$loopCnt == 0 ]]; then
                echo "\$userNotation Tomcat is not running"
            else
                echo "\$userNotation Tomcat has been stopped successfully"
            fi
            break
        fi
        # Increase the loop counter
        ((loopCnt++))
    done
}

forceStartTomcat() {
    local loopCnt=0
    while true; do
        sudo lsof -i :\$tomcatiListenPort
        if [[ \$? == 0 ]]; then
            if [[ \$loopCnt == 0 ]]; then
                echo "\$userNotation Tomcat is already running"
            else
                echo "\$userNotation Tomcat has been started successfully"
            fi
            break
        else
            # Check the loop limit
            if [[ \$loopCnt -ge \$loopMax ]]; then
                echo "\$userNotation Max loop reached, force start tomcat failed."
                break
            fi
            echo "\$userNotation Force start tomcat ..."
            # cd \$tomcatLogPath
            nohup sudo -u \$tomcatUser \$catalinaShellPath start &
            sleep \$startWaitTime
        fi
        # Increase the loop counter
        ((loopCnt++))
    done
}

forceRestartTomcat() {
    echo "\$userNotation Performing force restart tomcat ..."
    forceStopTomcat
    forceStartTomcat
}

updateIndex() {
    cd \$opengrokLogPath
    echo "\$userNotation Updating index ..."
    \$javaIndexerCommand
    if [[ \$? != 0 ]]; then
        echo "\$userNotation Update index failed, quitting now"
        exit 1
    fi
}

main() {
    if [[ \$fUpdateIndex == true ]]; then
        updateIndex
        forceRestartTomcat
    elif [[ \$fRestartTomcat == true ]]; then
        forceRestartTomcat
    elif [[ \$fStartTomcat == true ]]; then
        forceStartTomcat
    elif [[ \$fStopTomcat == true ]]; then
        forceStopTomcat
    fi
}

# set -x
cd \$opengrokLogPath
main
_EOF
    chmod +x $indexerFilePath

    if [[ -L $indexerLinkTarget ]]; then
        echo "$userNotation Soft link $indexerLinkTarget already exist. Skipping ln -sf"
    else
        echo "$userNotation Making soft link /bin/callIndexer"
        sudo ln -sf $indexerFilePath $indexerLinkTarget
    fi
}

summary() {
    cat > $summaryTxt << _EOF
Universal Ctags Path = $uCtagsBinPath
Java Home = $javaInstDir
Java Path = $javaPath
Tomcat Home = $tomcatInstDir
Tomcat Version = $tomcatVersion
Opengrok Instance Base = $openGrokInstanceBase
Opengrok Source Root = $openGrokSrcRoot => $systemSrcRoot
Indexer Path: $indexerLinkTarget -> $indexerFilePath
Server at: http://127.0.0.1:${newListenPort}/source
_EOF

cat << _EOF
$catBanner
$(cat $summaryTxt)
_EOF
# Print the logo
logo
}

setEnv() {
    cat << _EOF
$catBanner
Setting Environment Variables for Catalina/Tomcat
_EOF
    # Fix Permission denied error using tee
    cat << _EOF | sudo tee $setEnvFilePath
#!/bin/bash
export JAVA_HOME=${JAVA_HOME}
export JRE_HOME=${JAVA_HOME}
export CLASSPATH=${JAVA_HOME}/lib:${JRE_HOME}/lib
export TOMCAT_USER=${tomcatUser}
export TOMCAT_HOME=${TOMCAT_HOME}
export CATALINA_HOME=${TOMCAT_HOME}
export CATALINA_BASE=${TOMCAT_HOME}
export CATALINA_TMPDIR=${TOMCAT_HOME}/temp
export CATALINA_PID=${catalinaPIDFile}
export OPENGROK_INSTANCE_BASE=${openGrokInstanceBase}
export OPENGROK_TOMCAT_BASE=$CATALINA_HOME
export OPENGROK_SRC_ROOT=$openGrokSrcRoot
export OPENGROK_CTAGS=$uCtagsBinPath
export UCTAGS_INSTALL_DIR=$uCtagsInstDir
_EOF
    # make it executable
    sudo chmod +x $setEnvFilePath
}

callIndexer() {
    cat << _EOF
$catBanner
Calling Indexer
_EOF
    if [[ ! -f $indexerFilePath ]]; then
        echo "Indexer file $indexerFilePath does not exist, quitting now"
        exit 1
    fi
    $indexerFilePath -u
    if [[ $? != 0 ]]; then
        echo "Call indexer failed, quitting now"
        exit 1
    fi
}

checkDirsIfExist() {
    cat << _EOF
$catBanner
Checking Directories
_EOF
    if [[ ! -d $systemSrcRoot ]]; then
        sudo mkdir -p $systemSrcRoot
    fi
    local srcRootOwner=`ls -ld $systemSrcRoot | awk '{print $3}'`
    if [[ "$srcRootOwner" != "$USER" ]]; then
        sudo chown -R $USER:$GROUPS $systemSrcRoot
    fi

    if [[ ! -d $downloadPath ]]; then
        mkdir -p $downloadPath
    fi

    if [[ ! -d $loggingPath ]]; then
        mkdir -p $loggingPath
    fi

    if [[ ! -d $openGrokInstanceBase ]]; then
        sudo mkdir -p ${openGrokInstanceBase}/{data,dist,etc,log}
        sudo chown -R $USER:$GROUPS $openGrokInstanceBase
    fi

    # make a soft link to /opt/src
    if [[ -L $openGrokSrcRoot ]]; then
        echo "$userNotation Soft link $openGrokSrcRoot already exist. Skipping ln -sf"
    else
        ln -sf $systemSrcRoot $openGrokSrcRoot
    fi
}

main() {
    checkDirsIfExist
    # preInstallForUbuntu
    installuCtags
    installJdk
    installTomcat
    installOpenGrok
    makeIndexer
    setEnv
    callIndexer
    summary
}

main