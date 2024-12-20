#!/bin/bash
# set -x

# Misc Info
fMainWd=$(cd $(dirname $0); pwd)
fJobs=$(nproc)
fCommInstPath=/opt
fDownPath=$fMainWd/downloads
fLoggingPath=$fMainWd/logs
fSummaryTxt=$fMainWd/summary.txt
fSysSrcRoot=/opt/src
# Universal Ctags Info
uCtagsInstDir=$fCommInstPath/uctags
# Jdk Info - via apt install
jdkSystemInstalledVersion=openjdk-11-jdk
jdkInstDir=/usr/lib/jvm/java-11-openjdk-amd64
javaInstDir=$jdkInstDir
javaPath=$javaInstDir/bin/java
JAVA_HOME=$javaInstDir
# Tomcat Info
tomcatVersion=10.1.13
TOMCAT_HOME=$fCommInstPath/tomcat
CATALINA_HOME=$TOMCAT_HOME
tomcatInstDir=$TOMCAT_HOME
tomcatUser=tomcat
tomcatGrp=tomcat
setEnvFileName=setenv.sh
setEnvFilePath=$CATALINA_HOME/bin/$setEnvFileName
catalinaShellPath=$tomcatInstDir/bin/catalina.sh
catalinaPIDFile=$tomcatInstDir/temp/tomcat.pid
catalinaGetVerCmd=$tomcatInstDir/bin/version.sh
newListenPort=8080
# serverXmlPath=${tomcatInstDir}/conf/server.xml
# srvXmlTemplate=$mainWd/template/server.xml
# OpenGrok Info
openGrokVersion=1.12.12
openGrokInstDir=$fCommInstPath/opengrok
openGrokTarName=opengrok-$openGrokVersion.tar.gz
openGrokUntarDir=opengrok-$openGrokVersion
openGrokPath=$fDownPath/$openGrokUntarDir
openGrokInstanceBase=$openGrokInstDir
openGrokSrcRoot=$openGrokInstanceBase/src
# OpenGrok Indexer Info
indexerFileName=call_indexer
indexerFilePath=$fMainWd/$indexerFileName
indexerLinkTarget=/bin/callIndexer
# Constants
BANNER="---------------------------------------------------"
BANNER=$(echo "$BANNER" | sed 's/------/------ /g')
USERNOTATION="@@@@"
# Colors
CYAN='\033[36m'
RED='\033[31m'
BOLD='\033[1m'
GREEN='\033[32m'
MAGENTA='\033[35m'
BLUE='\033[34m'
GREY='\033[90m'
LIGHTYELLOW='\033[93m'
# YELLOW='\033[33m'
RESET='\033[0m'
COLOR=$MAGENTA

logo() {
    cat << "_EOF"
  ___  _ __   ___ _ __   __ _ _ __ ___ | | __
 / _ \| '_ \ / _ \ '_ \ / _` | '__/ _ \| |/ /
| (_) | |_) |  __/ | | | (_| | | | (_) |   <
 \___/| .__/ \___|_| |_|\__, |_|  \___/|_|\_\
      |_|               |___/

_EOF
}

usage() {
    cat << _EOF
Usage: $(basename $0) [-h]
Options:
    -h: Print this help message

_EOF
    logo
    exit 1
}

while getopts "h" opt; do
    case $opt in
        h)
            usage
            ;;
        ?)
            echo -e "${COLOR}Invalid option: -$OPTARG${RESET}" 2>&1
            exit 1
            ;;
    esac
done

preInstallForUbuntu() {
    echo -e "${COLOR}Pre-Installing for Ubuntu${RESET}"
    sudo apt-get update
    sudo apt-get install -y \
            pkg-config libevent-dev build-essential cmake \
            automake curl autoconf libtool python3 net-tools
}

installuCtags() {
    echo -e "${COLOR}Installing Universal Ctags${RESET}"

    # Check if the 'ctags' command is available
    if command -v ctags &> /dev/null; then
        # Check if 'ctags' is Universal Ctags
        if ctags --version | grep -i -q 'universal'; then
            uCtagsBinPath=`which ctags`
            echo "$USERNOTATION Universal Ctags is already installed at: $uCtagsBinPath"
            $uCtagsBinPath --version
            return
        else
            echo "$USERNOTATION ctags is already installed, but it is not Universal Ctags."
            sudo apt-get remove exuberant-ctags -y
        fi
    fi

    if [[ ! -d $uCtagsInstDir ]]; then
        sudo mkdir -p $uCtagsInstDir
    fi

    cd "$fDownPath" || exit
    local clonedName=ctags
    if [[ -d "$clonedName" ]]; then
        echo "$USERNOTATION Directory $clonedName already exist. Skipping git clone."
    else
        git clone https://github.com/universal-ctags/ctags
        if [[ $? != 0 ]]; then
            echo -e "${MAGENTA}[Error]: git clone error, quitting now${RESET}"
            exit 255
        fi
    fi

    cd $clonedName || exit
    # pull the latest code
    git pull
    ./autogen.sh
    ./configure --prefix=$uCtagsInstDir
    make -j"$fJobs"
    if [[ $? != 0 ]]; then
        echo -e "${COLOR}[Error]: make error, quitting now${RESET}"
        exit 255
    fi

    sudo make install
    if [[ $? != 0 ]]; then
        ech -e "${COLOR}[Error]: make install error, quitting now${RESET}"
        exit 255
    fi

    uCtagsBinPath=$uCtagsInstDir/bin/ctags
    # create a soft link to /bin/ctags
    sudo ln -sf $uCtagsBinPath /bin/ctags

    cat << _EOF
$BANNER
Ctags Path = /bin/bash -> $uCtagsBinPath
$($uCtagsBinPath --version)
_EOF
}

installJdk() {
    echo -e "${COLOR}Installing JDK${RESET}"

    if [[ -x $javaPath ]]; then
        echo "$USERNOTATION JDK is already installed at: $javaInstDir"
        $javaPath --version
        return
    fi
    sudo apt-get install $jdkSystemInstalledVersion -y

    cat << _EOF
$BANNER
Java Package Install Path = $javaInstDir
Java Path = $javaPath
$($javaPath -version)
_EOF
}

installTomcat() {
    echo -e "${COLOR}Installing Tomcat${RESET}"

    if [[ -x $catalinaGetVerCmd ]]; then
        echo "$USERNOTATION Tomcat is already installed at: $tomcatInstDir"
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

        cd "$fDownPath" || exit
        # Download the latest Tomcat 10 release
        if [[ -f "$tomcatTarName" ]]; then
            ech -e "${USERNOTATION} File $tomcatTarName already exist. Skipping download."
        else
            wget "$tomcatUrl"
        fi
    else
        echo -e "${COLOR}[Error]: Failed to fetch the latest Tomcat 10 release version${RESET}"
        exit 1
    fi

    # untar into /opt/tomcat and strip one level directory
    if [ ! -d "$tomcatInstDir" ] || [ -z "$(ls -A "$tomcatInstDir" 2>/dev/null)" ]; then
        if [[ ! -d $tomcatInstDir ]]; then
            sudo mkdir -p $tomcatInstDir
        fi
        sudo tar -zxv -f "$tomcatTarName" --strip-components=1 -C $tomcatInstDir
        if [[ $? != 0 ]]; then
            echo [Error]: untar tomcat package error, quitting now
            exit
        fi
    else
        echo -e "${USERNOTATION} Directory $tomcatInstDir already exist and not empty. Skipping untar."
    fi

    # change owner:group of TOMCAT_HOME
    tomcatOwner=`ls -ld $tomcatInstDir | awk '{print $3}'`
    if [[ "$tomcatOwner" == "$tomcatUser" ]]; then
        echo "$USERNOTATION Tomcat owner is already $tomcatUser, skipping chown"
    else
        sudo chown -R $tomcatUser:$tomcatGrp $tomcatInstDir
    fi

    local deployCheckPoint=$tomcatInstDir/webapps/
    if [ "$(stat -c %a $deployCheckPoint)" -eq 755 ]; then
        echo -e "${USERNOTATION} Directory $deployCheckPoint already has 755 permission"
    else
        sudo chmod -R 755 $tomcatInstDir
    fi

    # clear the temp dir in tomcat
    sudo rm -rf $tomcatInstDir/temp/*

    cat << _EOF
$BANNER
Tomcat Version Name = $tomcatFullName
Tomcat Install Path = $tomcatInstDir
_EOF
}

installOpenGrok() {
    echo -e "${COLOR}Installing OpenGrok v$openGrokVersion${RESET}"

    local downBaseUrl=https://github.com/oracle/opengrok/releases/download/
    downloadUrl=$downBaseUrl/$openGrokVersion/$openGrokTarName

    cd "$fDownPath" || exit
    # check if already has tar ball downloaded
    if [[ -f $openGrokTarName ]]; then
        echo -e "${USERNOTATION} File $openGrokTarName already exist. Skipping download."
    else
        wget --no-cookies \
             --no-check-certificate \
             --header "Cookie: oraclelicense=accept-securebackup-cookie" \
             "$downloadUrl" \
             -O $openGrokTarName
        # check if wget returns successfully
        if [[ $? != 0 ]]; then
            echo "$USERNOTATION wget $downloadUrl failed, quitting now"
            exit 1
        fi
    fi

    if [[ ! -d $openGrokUntarDir ]]; then
        tar -zxvf $openGrokTarName
    else
        echo -e "${USERNOTATION} Directory $openGrokUntarDir already exist. Skipping untar."
    fi

    # Info about OpenGrok Web Application
    local warFileName=source.war
    warFilePath=$openGrokUntarDir/lib/$warFileName
    cd $openGrokUntarDir || exit

    # If user does not use default OPENGROK_INSTANCE_BASE then attempt to
    # extract WEB-INF/web.xml from source.war using jar or zip utility, update
    # the hardcoded values and then update source.war with the new
    # WEB-INF/web.xml.
    if [[ "$openGrokInstanceBase" != "/var/opengrok" ]]; then
        cd lib || exit
        if [[ ! -f $warFileName ]]; then
            echo "$USERNOTATION File $warFileName does not exist, quitting now"
            exit 1
        fi
        # Extract and overwrite the WEB-INF/web.xml file from source.war archive.
        unzip -o $warFileName WEB-INF/web.xml

        # Change the hardcoded values in WEB-INF/web.xml
        cd WEB-INF || exit
        local webXmlName=web.xml
        local changeFrom=/var/opengrok/etc/configuration.xml
        local changeTo=$openGrokInstanceBase/etc/configuration.xml
        if grep -q "$changeTo" "$webXmlName"; then
            echo "$USERNOTATION WEB-INF/web.xml already updated, skipping sed and zip -u"
        else
            # update web.xml
            sed -i -e 's:'"$changeFrom"':'"$changeTo"':g' "$webXmlName"
            cd ..
            echo "$USERNOTATION Updating source.war with new WEB-INF/web.xml"
            zip -u source.war WEB-INF/web.xml &>/dev/null
            if [[ $? != 0 ]]; then
                echo "$USERNOTATION zip -u source.war WEB-INF/web.xml failed, quitting now"
                exit 1
            fi
        fi
    fi

    # copy source.war to tomcat webapps
    tomcatWebAppsDir=$tomcatInstDir/webapps
    cd "$fDownPath" || exit
    sudo -u $tomcatUser cp -f $warFilePath $tomcatWebAppsDir
    if [[ $? != 0 ]]; then
        echo "$USERNOTATION copy $warFilePath to $tomcatWebAppsDir failed, quitting now"
        exit 2
    fi

    # fix one warning
    cp -f "$fDownPath"/$openGrokUntarDir/doc/logging.properties \
               ${openGrokInstanceBase}/etc
}

makeIndexer() {
    echo -e "${COLOR}Making Indexer $indexerFileName${RESET}"

    local loggingPropertyFile=$openGrokInstanceBase/etc/logging.properties
    javaIndexerCommand=$(echo $javaPath \
        -Djava.util.logging.config.file=$loggingPropertyFile \
        -jar "$openGrokPath"/lib/opengrok.jar \
        -c $uCtagsBinPath \
        -s $openGrokSrcRoot \
        -d $openGrokInstanceBase/data -H -P -S -G \
        -W $openGrokInstanceBase/etc/configuration.xml)

    # The indexer will generate opengrok0.0.log at the same directory
    # But I'd like it to generate log file at $loggingPath
    if [[ ! -d $fLoggingPath ]]; then
        mkdir -p "$fLoggingPath"
    fi

    cat << _EOF > "$indexerFilePath"
#/bin/bash
# Run Tomcat service as user tomcat
tomcatUser=$tomcatUser
tomcatGrp=$tomcatGrp
catalinaShellPath=$catalinaShellPath
tomcatiListenPort=$newListenPort
opengrokLogPath="$fLoggingPath"
# tomcatLogPath="$tomcatInstDir/logs"
javaIndexerCommand="$javaIndexerCommand"
# Flags
fUpdateIndex=false
fRestartTomcat=false
fStartTomcat=false
fStopTomcat=false
# User notation
USERNOTATION=$USERNOTATION
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
            echo "\$USERNOTATION Invalid option: -\$OPTARG" 2>&1
            exit 1
            ;;
    esac
done

# Shift to process non-option arguments. New \$1, \$2, ..., \$@
shift \$((OPTIND - 1))
if [ \$# -gt 0 ]; then
    echo "\$USERNOTATION Illegal non-option arguments: \$@"
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
                echo "\$USERNOTATION Max loop reached, force stop tomcat failed."
                break
            fi
            echo "\$USERNOTATION Force stop tomcat ..."
            sudo \$catalinaShellPath stop -force
            sleep \$stopWaitTime
        else
            if [[ \$loopCnt == 0 ]]; then
                echo "\$USERNOTATION Tomcat is not running"
            else
                echo "\$USERNOTATION Tomcat has been stopped successfully"
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
                echo "\$USERNOTATION Tomcat is already running"
            else
                echo "\$USERNOTATION Tomcat has been started successfully"
            fi
            break
        else
            # Check the loop limit
            if [[ \$loopCnt -ge \$loopMax ]]; then
                echo "\$USERNOTATION Max loop reached, force start tomcat failed."
                break
            fi
            echo "\$USERNOTATION Force start tomcat ..."
            # cd \$tomcatLogPath
            nohup sudo -u \$tomcatUser \$catalinaShellPath start &
            sleep \$startWaitTime
        fi
        # Increase the loop counter
        ((loopCnt++))
    done
}

forceRestartTomcat() {
    echo "\$USERNOTATION Performing force restart tomcat ..."
    forceStopTomcat
    forceStartTomcat
}

updateIndex() {
    cd \$opengrokLogPath
    echo "\$USERNOTATION Updating index ..."
    \$javaIndexerCommand
    if [[ \$? != 0 ]]; then
        echo "\$USERNOTATION Update index failed, quitting now"
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
    chmod +x "$indexerFilePath"

    if [[ -L $indexerLinkTarget ]]; then
        echo -e "${USERNOTATION} Soft link $indexerLinkTarget already exist. Skipping ln -sf"
    else
        echo -e "${USERNOTATION} Creating soft link $indexerLinkTarget -> $indexerFilePath"
        sudo ln -sf "$indexerFilePath" $indexerLinkTarget
    fi
}

summary() {
    cat > "$fSummaryTxt" << _EOF
Universal Ctags Path = $uCtagsBinPath
Java Home = $javaInstDir
Java Path = $javaPath
Tomcat Home = $tomcatInstDir
Tomcat Version = $tomcatVersion
Opengrok Instance Base = $openGrokInstanceBase
Opengrok Source Root = $openGrokSrcRoot => $fSysSrcRoot
Indexer Path: $indexerLinkTarget -> $indexerFilePath
Server at: http://127.0.0.1:${newListenPort}/source
_EOF

cat << _EOF
$BANNER
$(cat "$fSummaryTxt")
_EOF
# Print the logo
logo
}

setEnv() {
    echo -e "${COLOR}Setting Environment Variables for Catalina/Tomcat${RESET}"

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
    echo -e "${COLOR}Calling Indexer${RESET}"
    if [[ ! -f $indexerFilePath ]]; then
        echo -e "${COLOR}indexer $indexerFilePath does not exist, quitting now${RESET}"
        exit 1
    fi
    $indexerFilePath -u
    if [[ $? != 0 ]]; then
        echo -e "${COLOR}Running indexer failed, quitting now${RESET}"
        exit 1
    fi
}

sanityCheck() {
    echo -e "${COLOR}Sanity Check${RESET}"

    if [[ ! -d $fSysSrcRoot ]]; then
        sudo mkdir -p $fSysSrcRoot
    fi
    local srcRootOwner=`ls -ld $fSysSrcRoot | awk '{print $3}'`
    if [[ "$srcRootOwner" != "$USER" ]]; then
        sudo chown -R $USER:$GROUPS $fSysSrcRoot
    fi

    if [[ ! -d $fDownPath ]]; then
        mkdir -p "$fDownPath"
    fi

    if [[ ! -d $fLoggingPath ]]; then
        mkdir -p "$fLoggingPath"
    fi

    if [[ ! -d $openGrokInstanceBase ]]; then
        sudo mkdir -p ${openGrokInstanceBase}/{data,dist,etc,log}
        sudo chown -R $USER:$GROUPS $openGrokInstanceBase
    fi

    # make a soft link to /opt/src
    if [[ -L $openGrokSrcRoot ]]; then
        echo -e "${USERNOTATION} Soft link $openGrokSrcRoot already exist. Skipping ln -sf"
    else
        ln -sf $fSysSrcRoot $openGrokSrcRoot
    fi
}

main() {
    sanityCheck
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
