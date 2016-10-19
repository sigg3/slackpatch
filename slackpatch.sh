#!/bin/bash
#
# Simple Slackware patching tool created in 2016 by Sigg3.net
# Copyright (C) 2016 Sigbjoern "Sigg3" Smelror <me@sigg3.net>.
#
# slackpatch is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation, version 3 of the License.
#
# slackpatch is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# Full license terms: <http://www.gnu.org/licenses/gpl-3.0.txt>
#
# # # # # # # # # # # # # # # # #
SERVER="ftp.slackware.com"        # LEAVE AS-IS or change to a local mirror of ftp.slackware.com (or custom repo)
VERSION=""                         # LEAVE EMPTY for auto detection or use 13.0 .. 14.2 OR current
DESK="/root/slackpatch"             # script working directory (root will administer these files)
SLACKPATCH="slackpatch 0.6"          # obligatory vanity field (including version)
REPO="$DESK/$SERVER"                   # downloaded listing of packages on $SERVER
BASE="$DESK/.upgrades.log"              # $REPO diff file for filtering updates
INSTALLED="/var/log/packages/"           # list of installed packages on system
MINION=$( logname )                       # used for downloading and managing files in /tmp
MESS="/tmp/slackpatch-$MINION/$(date +%N)"  # temp work directory (by $MINION user)
# # # # # # # # # # # # # # # # # # # # # # # #
#
# TODO change DESK to $logname/.slackpatch/
#
# TODO output normal CLI stuff: version, help, usage info
#
# TODO cleanup file names (please use descriptive names)
#
# TODO integrate sources from slackpkg update?
#
# Runtime # . . .
Title() {
	clear && echo "== $SLACKPATCH by sigg3.net =="
}

# Got root?
if (( UID )) ; then
	Title
	echo -e "Error: You must have root. Run script like this: $ su -c '$0'\nYou can also 'su' into root and run $0 since \$logname is preserved.\n"
	echo -e "Note:  Root privileges are not used for downloading, only upgradepkg.\nDownloads are run in the equivalent of: $ su -c 'su \$(logname) -c curl ...'"
	exit 1
else
	Title && cat <<"EOT"
slackpatch is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the GNU General Public License for details.
Full license terms: <http://www.gnu.org/licenses/gpl-3.0.txt>

WARNING: Before upgrading a package, save any configuration files that you wish
to keep (such as in /etc). Sometimes these will be preserved, but it depends on
the package structure. If you want to force new versions of the config files to
be installed, remove the old ones manually prior to running slackpatch.

Don't worry, person. slackpatch will ask before doing anything dangerous.
EOT
	echo -e "\n\n" && read -p "Type 'OK' to continue: " OPT
	case "$OPT" in
		"ok" | "OK" | "Ok" ) Title ;;
		* ) exit 0 ;;
	esac
fi

for dep in "curl" "md5sum" "upgradepkg" "su" "logname" ; do
	case "$dep" in       #
		upgradepkg ) UPGRADE=$( which $dep ) ;;
		su )              SU=$( which $dep ) ;;
		* ) TEST=$( which $dep &>/dev/null ) ;;
	esac                 #
	[[ "$?" = 1 ]] && echo "Error: missing dependency $dep" && exit 1
done

# Test version
SLACKFILE="/etc/slackware-version"
if [[ -f "$SLACKFILE" ]] ; then
	TEST=$( sed "s/Slackware //g" "$SLACKFILE" )
	if [[ -z "$VERSION" ]] ; then
		VERSION="$TEST"
	else
		[[ "$TEST" != "$VERSION" ]] && echo "Error: version mismatch. $VERSIONFILE says $TEST not $VERSION." && exit 1
	fi
else
	[[ -z "$VERSION" ]] && echo "Error: \$VERSION cannot be empty when $SLACKFILE is missing." && exit 1
fi

# Construct URLs
ARCH=$( uname -m )
WEB="$SERVER/pub/slackware/slackware" && [[ "$ARCH" = "x86_64" ]] && WEB+="64"
WEB+="-$VERSION/patches" && CHECKSUMS="$WEB/CHECKSUMS.md5" && WEB+="/packages"

# Output config and test network
echo -en "Running $SLACKPATCH for Slackware $VERSION $ARCH\n\nusr: $MINION (used for downloading)\nsys: Slackware $VERSION $ARCH\nsrc: $WEB "
if [[ $( ping -c 1 "$SERVER" | grep -o "[0-9] received" | sed 's/.received//g' ) = 1 ]] ; then
	echo -e "(online)\ndir: $DESK/\n"
else
	echo -e "(offline)\n\nError: $SERVER does not respond to ping." && exit 1
fi

# Functions
AsUser() { # Run $1 as loguser $MINION (also works when logged in as root from a previous user shell.)
	"$SU" "$MINION" -c "$1"
}
CleanUp() { # Removes unwanted cruft
	[[ -z "$1" ]] && local EXIT_CODE=0 || local EXIT_CODE="$1"
	echo "Cleaning up.."
	#echo "Debug" && exit $EXIT_CODE # Comment this when done
	[[ -d "$MESS/" ]]                  && rm -Rfv "$MESS/"
	[[ -f "$REPO" ]]                   && rm -fv "$REPO"
	[[ -f "$DESK/updates" ]]           && rm -fv "$DESK/updates"
	[[ -f "$DESK/updates.diff" ]]      && rm -fv "$DESK/updates.diff"
	[[ -f "$DESK/updates.actual" ]]    && rm -fv "$DESK/updates.actual"
	[[ -f "$DESK/updates.filtered" ]]  && rm -fv "$DESK/updates.filtered"
	[[ -f "$DESK/updates.installed" ]] && rm -fv "$DESK/updates.installed"
	echo -e "\nDone. (code $EXIT_CODE)"
	exit $EXIT_CODE
}
trap CleanUp SIGHUP SIGINT SIGTERM

# Create work and temporary directories
[[ ! -d "$DESK/" ]] && mkdir -p "$DESK/"
[[ ! -d "$MESS/" ]] && AsUser "mkdir -p $MESS/"

AsUser "curl -s -l ftp://$WEB/ > $MESS/.listing" # Get package listing from $SERVER (REPO)
[[ "$?" != 0 ]] && echo "Error: could not retrieve repo list from $WEB (curl err $?)" && CleanUp 1
cp "$MESS/.listing" "$REPO" # secondary operation necessary since curl above is run as normal user

# Check against existing log $BASE
if [[ -f "$BASE" ]] ; then
	grep ".txz" "$REPO" | grep -v ".asc" > "$DESK/updates.diff"
	sort -o "$DESK/updates.diff" "$DESK/updates.diff"
	sort -o "$BASE" "$BASE"
	diff "$BASE" "$DESK/updates.diff" | sed '1d' | tr -d ">" | tr -d "<" | tr -d " " > "$DESK/updates"
	UPDATES=$( cat "$DESK/updates" | wc -l ) && [[ "$UPDATES" = 0 ]] && echo -e "Status: No new updates available.\n" && CleanUp 0
else
	cp "$REPO" "$DESK/updates"
	sort -o "$BASE" "$BASE"
fi

# Filter list of updates (txz only and not packages already installed)
grep ".txz" "$DESK/updates" | grep -v ".asc" > "$DESK/updates.actual" && mv -f "$DESK/updates.actual" "$DESK/updates"
while read -r ; do IS_INSTALLED=$( find "$INSTALLED" -name "${REPLY:0:-4}" | wc -l ) && [[ "$IS_INSTALLED" -gt 0 ]] && echo "${REPLY:0:-4}" >> "$DESK/updates.installed" ; done < "$DESK/updates"
while read -r ; do grep -v "$REPLY" "$DESK/updates" >> "$DESK/updates.filtered" ; mv -f "$DESK/updates.filtered" "$DESK/updates" ; done < "$DESK/updates.installed"
[[ -f "$DESK/updates.installed" ]] && rm -f "$DESK/updates.installed"
awk '!a[$0]++' "$DESK/updates" > "$DESK/updates.actual" && mv -f "$DESK/updates.actual" "$DESK/updates" # remove duplicates

# Output names of updates (if any) and prompt for permission
UPDATES=$(cat "$DESK/updates" | wc -l)

case "$UPDATES" in
	0 ) echo -e "Status: No new updates available.\n" && CleanUp 0 ;;
	1 ) echo -e "Status: There is 1 updated package available:\n"  ;;
	* ) echo -e "Status: There are $UPDATES updates available:\n"  ;;
esac
while read -r ; do echo -e "* $REPLY\n" ; done < "$DESK/updates"
read -p "Retrieve package updates and perform upgrade? Type 'yes': " OPT
case "$OPT" in
	"Yes" | "yes" | "YES" ) echo -en "\nFetching CHECKSUMS.md5 .." ;;
	* )                     echo "Aborting update." && CleanUp 0   ;;
esac

# Get checksums file from $SERVER
AsUser "curl -s -o $MESS/CHECKSUMS.md5 -L ftp://$CHECKSUMS"
[[ "$?" != 0 ]] && echo -e "\nError: Could not fetch ftp://$CHECKSUMS (curl err $?)" && CleanUp || echo ".. OK."

# Upgrade loop
while read -u 3 -r software ; do
	software=$( echo "$software" | tr -d '\r' ) # remove carriage return
	AsUser "curl -s -o $MESS/$software -L ftp://$WEB/$software"
	[[ "$?" != 0 ]] && echo "Error: Could not retrieve $software (curl err $?)" && continue
	SOFT_MD5SUM=$( md5sum "$MESS/$software" | head -c 32 )
	LIST_MD5SUM=$( grep "$software" "$MESS/CHECKSUMS.md5" | grep -v ".asc" | awk '{ print $1 }')
	if [[ "$SOFT_MD5SUM" = "$LIST_MD5SUM" ]] ; then
		INSTALL=0 && clear && echo "$software - checksum matches"
	else
		INSTALL=1 && echo "Error: Checksum of $software does not match"
	fi
	echo -e "\nFILE:\t$SOFT_MD5SUM ($software)\nLIST:\t$LIST_MD5SUM (CHECKSUMS.md5)\n"
	if [[ "$INSTALL" = 0 ]] ; then
		read -sn 1 -p "Do you want to upgrade $software [Y/n]? " OPT
		case "$OPT" in
			y | Y ) "$UPGRADE" "$MESS/$software" && echo "$software" >> "$BASE" ;;
			* )     echo "Not installing $software .." && sleep 1               ;;
		esac
	else
		echo "Skipping $software" && sleep 1
	fi
done 3< "$DESK/updates"

CleanUp
