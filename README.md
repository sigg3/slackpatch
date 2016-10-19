`                    ____  _____    _    ____  __  __ _____ 
                   |  _ \| ____|  / \  |  _ \|  \/  | ____|
                   | |_) |  _|   / _ \ | | | | |\/| |  _|  
                   |  _ <| |___ / ___ \| |_| | |  | | |___ 
                   |_| \_\_____/_/   \_\____/|_|  |_|_____|`

Slackpatch is a hillbilly update tool for Slackware systems with lazy admins.
It uses curl to check ftp.slackware.com for patches for your Slackware version,
lists and, if you want to, downloads and installs them.

Slackpatch supports Slackware versions 13 through -current (32 and 64-bit).

Caveat, this script uses upgradepkg so the same straight-forwardness applies.
Before upgrading a package, save any configuration files that you wish to 
keep (such as in /etc). Sometimes these will be preserved, but it depends on
the package structure. If you want to force new versions of the config files
to be installed, remove the old ones manually prior to running slackpatch.
The script asks for permission before each upgrade (no auto-assume yes here).

`        Usage: su -c './slackpatch.sh'`

Slackpatch will use the $logname builtin to run most commands as the regular
user and not root, but requires root for actual upgrades.

Hopefully, this will be useful to someone else:)  ~~ sigg3.net (2016)
