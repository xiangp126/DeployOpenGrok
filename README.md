### Illustrate
- This project aims to deploy **OpenGrok** easily and quickly
- Add manually deploy method, preferred than `wrapper`
- [Optional] build python tools instead of legacy bash scripts along with `OpenGrok`'s update
- Imcremental installation and subsequential handling all in `oneKey`
- Provide serveral handy scripts and packages
- Support `Mac` since tag `v2.9`
- Take my [Giggle](http://giggle.ddns.net:8080/source) as an example and refer [Guide](./gif/guide.gif) for how to use
<table width=100%>
    <tr align=center>
        <th colspan=2>Tools</th>
        <th>Originally?</th>
        <th>Usage</th>
        <th>Comment</th>
    </tr>
    <tr>
        <td rowspan=7>Common</td>
        <td><strong>callIndexer</strong></td>
        <td align=center>&Chi;</td>
        <td>./callIndexer</td>
        <td>generated by oneKey routine</td>
    </tr>
    <tr>
        <td>oneKey.sh</td>
        <td align=center>&radic;</td>
        <td>sh oneKey.sh</td>
        <td>lazy deploy main routine</td>
    </tr>
    <tr>
        <td>autopull.sh</td>
        <td align=center>&radic;</td>
        <td>sh autopull.sh</td>
        <td>auto update git repo and call indexer</td>
    </tr>
    <tr>
        <td>rsync.sh</td>
        <td align=center>&radic;</td>
        <td>sh rsync.sh</td>
        <td>rsync with remote server</td>
    </tr>
    <tr>
        <td>addcron.sh</td>
        <td align=center>&radic;</td>
        <td>sh addcron.sh</td>
        <td>add into crontab jobs</td>
    </tr>
    <tr>
        <td>dynamic.env</td>
        <td align=center>&Chi;</td>
        <td colspan=2 align=center>now deprecated, only for reference</td>
    </tr>
    <tr>
        <td>OpenGrok</td>
        <td colspan=2 align=center bgcolor=orange>1.1-rc74</td>
        <td align=left><a href=https://github.com/oracle/opengrok>opengrok official repository</a></td>
    </tr>
    <tr>
        <td>universal ctags</td>
        <td colspan=2 align=center>latest</td>
        <td align=left><a href=https://github.com/universal-ctags/ctags>universal ctags official</a></td>
    </tr>
    <tr>
        <td rowspan=1>Mac</td>
        <td><strong>catalina</strong></td>
        <td align=center>&Chi;</td>
        <td>catalina start<br> catalina stop</td>
        <td>brew install tomcat version 8<br>handle tomcat web service</td>
    </tr>
    <tr>
        <td rowspan=3>Linux</td>
        <td><strong>daemon.sh</strong></td>
        <td align=center>&Chi;</td>
        <td>./daemon start<br>./daemon stop</td>
        <td>generated by oneKey routine<br>handle tomcat web service</td>
    </tr>
    <tr>
        <td>tomcat</td>
        <td colspan=2 align=center bgcolor=orange>8.5.31</td>
        <td align=left><a href=./packages>tomcat local</a></td>
    </tr>
    <tr>
        <td>java</td>
        <td colspan=2 align=center bgcolor=orange>8u172</td>
        <td align=left><a href=./packages/jdk-splits>java fragments</a></td>
    </tr>
</table>

> Latest stable version: 3.0

### Lazy Deploy
#### clone `latch`
```bash
git clone https://github.com/xiangp126/Latch
```

#### set up source code

_put your source code into `OPENGROK_SRC_ROOT`, **per code per directory**_

#### `oneKey` procedure
```bash
sh oneKey.sh

[NAME]
    sh oneKey.sh -- setup OpenGrok through one key stroke

[SYNOPSIS]
    sh oneKey.sh [install | summary | help] [PORT]

[EXAMPLE]
    sh oneKey.sh [help]
    sh oneKey.sh install
    sh oneKey.sh install 8081
    sh oneKey.sh summary

[DESCRIPTION]
    install -> install opengrok, need root privilege but no sudo prefix
    help    -> print help page
    summary -> print tomcat/opengrok guide and installation info

[TIPS]
    Default listen-port is 8080 if [PORT] was omitted

  ___  _ __   ___ _ __   __ _ _ __ ___ | | __
 / _ \| '_ \ / _ \ '_ \ / _` | '__/ _ \| |/ /
| (_) | |_) |  __/ | | | (_| | | | (_) |   <
 \___/| .__/ \___|_| |_|\__, |_|  \___/|_|\_\
      |_|               |___/
```

```bash
sh oneKey.sh install
```

#### enjoy the site
> `indexer` was called in `oneKey`, you can also run `callIndexer` manually<br>
> take you server address as `127.0.0.1` for example<br>

_then browser your `http://127.0.0.1:8080/source`_

### Handle Web Service
#### mac
```bash
catalina stop
catalina start
```

#### linux
```bash
# repo main directory
sudo ./daemon stop
sudo ./daemon start
```

### Create Index Manually

#### python tools - new method
```bash
# repo main directory
./callIndexer
```

#### bash script - lagacy method
```bash
# make index of source (multiple index)
./OpenGrok index [/opt/o-source]
                  /opt/source   -- proj1
                                -- proj2
                                -- proj3
```

### Introduction to Handy tools
#### auto pull
_only support `Git` repository, auto re-indexing_

```bash
# Go into your OPENGROK_SRC_ROOT
pwd
/opt/o-source

ls
coreutils-8.21      dpdk-stable-17.11.2 glibc-2.7           libconhash
dpdk-stable-17.05.2 dpvs                keepalived          nginx
```

_add or remove item in *`updateDir`* of [autopull.sh](./autopull.sh)_

```bash
updateDir=(
    "dpvs"
    "keepalived"
    "Add Repo Name according to upper dir name"
)
```

_execute it_

```bash
sh autopull.sh
```

#### auto rsync
```bash
cat template/rsync.config
# config server info | rsync from
SSHPORT=
SSHUSER=
SERVER=
SRCDIR_ON_SERVER=

cp ./template/rsync.config .
vim rsync.config
# fix the information as instructed
```

```bash
sh rsync.sh
```

#### add cron
_chage the time as you wish in [addcron.sh](./addcron.sh)_

```bash
# Generate crontab file
cat << _EOF > $crontabFile
04 20 * * * $updateShellPath &> $logFile
_EOF
```

_and change *`updateShellPath`* as the shell needs auto executed by cron as you wish, default is `autopull.sh`_

```bash
updateShellPath=$mainWd/autopull.sh
```

_execute it_

```bash
sh addcron.sh
```

### Intelligence Window

hover over the item with mouse and press key `1` to launch `Intelligence Window`

press key `2` to **highlight or unhighlight** the item

### Attention
    If you use EZ-Zoom on Chrome with OpenGrok, make sure it's 100% or OpenGrok will jump to the wrong line

### Reference
- [Python-scripts-transition-guide](https://github.com/oracle/opengrok/wiki/Python-scripts-transition-guide)<br>
- [How-to-setup-OpenGrok](https://github.com/oracle/opengrok/wiki/How-to-setup-OpenGrok)

### License
The [MIT](./LICENSE.txt) License (MIT)
