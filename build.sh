#!/bin/zsh

# Make sure to check the README before running this script. There are various 
# required files that must be added first.

# MARK: Parse arguments

function show_usage {
	echo >&2 "Usage: $1 --platform (mac|mac-x86|windows) --config example"
}

zparseopts -D -E -F -A args -- \
	-platform: \
	-config:
local platform=$args[--platform]
local config=$args[--config]

if [[ -z $platform ]]
then
	show_usage $0
	exit 1
fi

if [[ -z $config ]]
then
	show_usage $0
	exit 1
fi

# MARK: Set variables

local buildpath="builds"
local filespath="files"
local sourcepath="source"
local success=false

local appname=
local version=
local build=
local bundleid=
local bundleidx86=
local team=
local filebase=
local quitmessage="Open the “File” menu and choose “Quit” or press {command}-Q on your keyboard to quit the current application. On the desktop, open the “Special” menu and choose “Shut Down.” Once the system has shut down, you can close {minivmac}."

while read line
do
	if [[ $line =~ ^([a-z0-9-]+):[[:space:]\s]*(.+)$ ]]
	then
		local key=$match[1]
		local value=$match[2]
		case $key in
			"app-name")      appname=$value;;
			"version")       version=$value;;
			"build")         build=$value;;
			"bundle-id")     bundleid=$value;;
			"bundle-id-x86") bundleidx86=$value;;
			"team")          team=$value;;
			"file-base")     filebase=$value;;
			"quit-message")  quitmessage=$value;;
		esac
	fi
done < "${filespath}/${config}.config"

if [[ -z $appname || -z $version || -z $build || -z $bundleid || -z $team || -z $filebase || -z $quitmessage ]]
then
	echo >&2 "Your config file is incomplete"
	exit 1
fi

# MARK: Create the quit message

if [[ $platform == "mac" || $platform == "mac-x86" ]]
then
	quitmessage=${quitmessage//{command}/Command}
else
	quitmessage=${quitmessage//{command}/Alt}
fi
quitmessage=${quitmessage//{minivmac}/^p}
quitmessage=${quitmessage//“/;[}
quitmessage=${quitmessage//”/;\{}
quitmessage=${quitmessage//‘/;]}
quitmessage=${quitmessage//’/;\}}

# MARK: Build the requested platform

if [[ $platform == "mac" || $platform == "mac-x86" ]]
then

	local minimum=11.0

	if [[ $platform == "mac-x86" ]]
	then
		print "Building Mac (Intel) version…"
		if [[ ! -z $bundleidx86 ]]
		then
			bundleid=$bundleidx86
			minimum=10.13
		fi
	else
		print "Building Mac (Apple Silicon) version…"
	fi

	print "Bundle ID: ${bundleid}"

	local projectpath="${sourcepath}/minivmac.xcodeproj/project.pbxproj"
	local infopath="${sourcepath}/cfg/Info.plist"
	local resourcespath="${sourcepath}/mnvm_dat"
	local iconpath="${sourcepath}/src/ICONAPPO.icns"

	rm -Rf "${resourcespath}"
	mkdir -p "${resourcespath}"
	cp "${filespath}/vMac.ROM" "${resourcespath}/vMac.ROM"
	cp "${filespath}/${filebase}.dsk" "${resourcespath}/disk1.dsk"

	iconutil -c icns "${filespath}/${filebase}.iconset" -o "${iconpath}"

	cd "${sourcepath}"
	gcc setup/tool.c -o setup_t

	# https://www.gryphel.com/c/minivmac/options.html
	if [[ $platform == "mac-x86" ]]
	then
		./setup_t -t mc64 -magnify 1 -speed z -bg 1 -svl 1 -sbx 1 > setup.sh	
	else
		./setup_t -t mcar -magnify 1 -speed z -bg 1 -svl 1 -sbx 1 > setup.sh
	fi

	chmod +x ./setup.sh
	./setup.sh
	cd ../

	scripts/xcode.py \
		--project "${projectpath}" \
		--info "${infopath}" \
		--bundleid $bundleid \
		--name $appname \
		--build $build \
		--version $version \
		--team $team \
		--minimum $minimum

	scripts/redefine.py \
		--file "source/src/STRCNENG.h" \
		--key kStrQuitWarningMessage \
		--string "${quitmessage}"

	print ""
	print "Manual steps:"
	print " - Open ${sourcepath}/minivmac.xcodeproj."
	print " - Add a \"Copy Files\" build phase. Select the destination \"Wrapper\" and enter"
	print "   the subpath \"Contents\". Add the folder \"mnvm_dat\"."
	print " - Archive, sign, and notarize the app."
	print ""

	print "Done"
	success=true

fi

if [[ $platform == "windows" ]]
then

	print "Building Windows version…"

	local basepath="${buildpath}/${appname}"
	local resourcespath="${basepath}/Resources"
	local zipname="${filebase}-windows.zip"

	mkdir -p "${basepath}"
	mkdir -p "${resourcespath}"
	cp "${filespath}/wx64/Mini vMac.exe" "${resourcespath}/Mini vMac.exe"
	cp "${filespath}/vMac.ROM" "${resourcespath}/vMac.ROM"
	cp "${filespath}/${filebase}.dsk" "${resourcespath}/disk1.dsk"

	# Create a shortcut to the exe. This is a pre-made shortcut that uses a
	# relative path: %COMSPEC% /C "start /b .\Resources\^"Mini vMac.exe^""
	cp "${filespath}/shortcut.lnk" "${basepath}/${appname}.lnk"

	# Create a bat file that launches the exe, an alternative to the shortcut
	# echo "@echo off\r\nstart /b .\Resources\\\"Mini vMac.exe\"" > \
	#	"${basepath}/${appname}.bat"

	cd "${buildpath}"
	rm -f "${zipname}"
	zip -r "${zipname}" "${appname}" -x "**/.DS_Store" "**/__MACOSX"
	rm -rf "${appname}"

	print "Done"
	success=true

fi

if [[ $success != true ]]
then
	echo >&2 "Unknown platform: ${platform}"
	exit 1
fi
