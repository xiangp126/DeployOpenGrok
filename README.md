### Introduction
I wrote this script to automate the deployment of OpenGrok on dev machine. It installs OpenGrok, Tomcat, and Universal Ctags.
It also generates a script to call the indexer. The script is tested on Ubuntu 20.04.2 LTS.

### Usage
```git
$ git clone https://github.com/xiangp126/latch

$ cd latch
$ sh oneKey_ubuntu.sh

$ cat summary.txt
Universal Ctags Path = /bin/ctags
Java Home = /usr/lib/jvm/java-11-openjdk-amd64
Java Path = /usr/lib/jvm/java-11-openjdk-amd64/bin/java
Tomcat Home = /opt/tomcat
Tomcat Version = 10.1.13.0
Opengrok Instance Base = /opt/opengrok
Opengrok Source Root = /opt/opengrok/src => /opt/src
Indexer File: Path/to/your/latch/call_indexer.sh <- /bin/callIndexer
Server at: http://127.0.0.1:8080/source
  ___  _ __   ___ _ __   __ _ _ __ ___ | | __
 / _ \| '_ \ / _ \ '_ \ / _` | '__/ _ \| |/ /
| (_) | |_) |  __/ | | | (_| | | | (_) |   <
 \___/| .__/ \___|_| |_|\__, |_|  \___/|_|\_\
      |_|               |___/
```

- During the first run, `call_indexer.sh` will be generated and linked to `/bin/callIndexer`
- Do not remove `latch` folder after installation. It is required by `callIndexer` to run.
- After the first run, you can then use `callIndexer` alone to index your source code.

### How to use callIndexer
```bash
$ callIndexer
Usage: /bin/callIndexer [-hursS]
Options:
    -h: Print this help message
    -u: Update index and restart Tomcat
    -r: Restart Tomcat only
    -s: Start Tomcat only
    -S: Stop Tomcat only

Example:
    /bin/callIndexer -u
    /bin/callIndexer -r
    /bin/callIndexer -s
    /bin/callIndexer -S

```

### Set up source code
Put your source code under `/opt/src`. One repo per folder.

And then call `callIndexer` to index your source code

```bash
$ callIndexer -u
```

### Illustrate
![](./gif/guide.gif)

#### How to Launch Intelligence Window
hover over the item with mouse and press key `1` (numeric 1) to launch `Intelligence Window`

#### key shortcuts
- key `2-7` to **highlight** or unhighlight the item
- key `8` to unhighlight all items

### Common Issues
#### `EZ-Zoom`
If you use `EZ-Zoom` on `Chrome` with OpenGrok, ensure it's **100%**, or OpenGrok will jump to a wrong line.

#### dyld library issue | `mac`
```bash
dyld: Library not loaded: /usr/local/opt/gettext/lib/libintl.8.dylib
  Referenced from: /usr/local/bin/wget
  Reason: image not found
[1]    15507 abort      wget
```

Brew installed what was missing; here is 'gettext'.

```bash
brew install gettext
```

### License
The [MIT](./LICENSE.txt) License (MIT)
