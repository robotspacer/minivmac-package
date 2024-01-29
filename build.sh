#!/bin/zsh

# Make sure to check the README before running this script. There are various 
# required files that must be added first.

# MARK: Parse arguments

function show_usage {
	echo >&2 "Usage: $1 --platform (mac|mac-intel|windows|dsk) --config example"
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

local maintainer="Paul C. Pratt"
local homepage="https://www.gryphel.com"

local build_path="builds"
local files_path="files"
local source_path="source"
local success=false

local app_name=
local version=
local build=
local bundle_id=
local bundle_id_intel=
local team=
local read_me=
local file_base=
local quit_message="Open the “File” menu and choose “Quit” or press {command}-Q on your keyboard to quit the current application. On the desktop, open the “Special” menu and choose “Shut Down.” Once the system has shut down, you can close {minivmac}."

while read line
do
	if [[ $line =~ ^([a-z0-9-]+):[[:space:]\s]*(.+)$ ]]
	then
		local key=$match[1]
		local value=$match[2]
		case $key in
			"app-name")        app_name=$value;;
			"version")         version=$value;;
			"build")           build=$value;;
			"bundle-id")       bundle_id=$value;;
			"bundle-id-intel") bundle_id_intel=$value;;
			"team")            team=$value;;
			"read-me")         read_me=$value;;
			"file-base")       file_base=$value;;
			"quit-message")    quit_message=$value;;
		esac
	fi
done < "${files_path}/${config}.config"

if [[ -z $app_name ||
      -z $version ||
      -z $build ||
      -z $bundle_id ||
      -z $team ||
      -z $file_base ||
      -z $quit_message ]]
then
	echo >&2 "Your config file is incomplete"
	exit 1
fi

# MARK: Create the quit message

if [[ $platform == "mac" ||
      $platform == "mac-intel" ]]
then
	quit_message=${quit_message//{command}/Command}
else
	quit_message=${quit_message//{command}/Alt}
fi
quit_message=${quit_message//{minivmac}/^p}
quit_message=${quit_message//“/;[}
quit_message=${quit_message//”/;\{}
quit_message=${quit_message//‘/;]}
quit_message=${quit_message//’/;\}}

# MARK: Build the requested platform

if [[ $platform == "mac" ||
      $platform == "mac-intel" ]]
then

	local minimum=11.0

	if [[ $platform == "mac-intel" ]]
	then
		print "Building Mac (Intel) version…"
		if [[ ! -z $bundle_id_intel ]]
		then
			bundle_id=$bundle_id_intel
			minimum=10.13
		fi
	else
		print "Building Mac (Apple Silicon) version…"
	fi

	print "Bundle ID: ${bundle_id}"

	local project_path="${source_path}/minivmac.xcodeproj/project.pbxproj"
	local info_path="${source_path}/cfg/Info.plist"
	local resources_path="${source_path}/mnvm_dat"
	local icon_path="${source_path}/src/ICONAPPO.icns"

	# Copy resources to the source directory
	rm -Rf "${resources_path}"
	mkdir -p "${resources_path}"
	cp "${files_path}/vMac.ROM" "${resources_path}/vMac.ROM"
	cp "${files_path}/${file_base}.dsk" "${resources_path}/disk1.dsk"

	# Replace the icon
	iconutil -c icns "${files_path}/${file_base}.iconset" -o "${icon_path}"

	# Set up the build script
	cd "${source_path}"
	gcc setup/tool.c -o setup_t
	# https://www.gryphel.com/c/minivmac/options.html
	if [[ $platform == "mac-intel" ]]
	then
		./setup_t \
			-t mc64 \
			-magnify 1 \
			-speed z \
			-bg 1 \
			-svl 1 \
			-sbx 1 \
			-maintainer "${maintainer}" \
			-homepage "${homepage}" \
			> setup.sh	
	else
		./setup_t \
			-t mcar \
			-magnify 1 \
			-speed z \
			-bg 1 \
			-svl 1 \
			-sbx 1 \
			-maintainer "${maintainer}" \
			-homepage "${homepage}" \
			> setup.sh
	fi
	chmod +x ./setup.sh
	./setup.sh
	cd ../

	# Update the Xcode project
	scripts/xcode.py \
		--project "$project_path" \
		--info "$info_path" \
		--bundleid "$bundle_id" \
		--name "$app_name" \
		--build "$build" \
		--version "$version" \
		--team "$team" \
		--minimum "$minimum"

	# Update the quit message
	scripts/redefine.py \
		--file "source/src/STRCNENG.h" \
		--key kStrQuitWarningMessage \
		--string "${quit_message}"

	print "Done"
	print ""
	print "Manual steps:"
	print " - Open ${source_path}/minivmac.xcodeproj in Xcode."
	print " - Add a \"Copy Files\" build phase. Select the destination \"Wrapper\" and enter"
	print "   the subpath \"Contents\". Add the folder \"mnvm_dat\"."
	print " - Archive, sign, and notarize the app."

	success=true

fi

if [[ $platform == "windows" ]]
then

	print "Building Windows version…"

	local base_path="${build_path}/${app_name}"
	local executable_path="${build_path}/minivmac-wx64.exe"
	local resources_path="${base_path}/Resources"
	local zip_name="${file_base}-windows.zip"

	if [ ! -f $executable_path ]
	then

		# Set up the build script
		cd "${source_path}"
		gcc setup/tool.c -o setup_t
		# https://www.gryphel.com/c/minivmac/options.html
		./setup_t \
			-e mgw \
			-t wx64 \
			-magnify 1 \
			-speed z \
			-bg 1 \
			-svl 1 \
			-maintainer "${maintainer}" \
			-homepage "${homepage}" \
			> setup.sh
		# Fix unexpected \x{FEFF} characters
		sed 's/﻿printf/printf/g' setup.sh > setup-new.sh
		mv setup-new.sh setup.sh
		chmod +x ./setup.sh
		./setup.sh
		cd ../

		# Update the quit message
		scripts/redefine.py \
			--file "source/src/STRCNENG.h" \
			--key kStrQuitWarningMessage \
			--string "${quit_message}"

		cd "${source_path}"

		# Update the Makefile to use MinGW-w64 
		local gcc="gcc=x86_64-w64-mingw32-gcc"
		local strip="strip=x86_64-w64-mingw32-strip"
		local windres="windres=x86_64-w64-mingw32-windres"
		local makefile=$(sed 's/gcc.exe/$(gcc)/g' Makefile)
		makefile=$(sed 's/strip.exe/$(strip)/g' <<< $makefile)
		makefile=$(sed 's/windres.exe/$(windres)/g' <<< $makefile)
		makefile=$(sed 's/^\(mk_COptionsCommon = .*\)$/\1 -Wno-unused-function /g' <<< $makefile)
		makefile="$gcc\n$strip\n$windres\n\n$makefile"
		echo "$makefile" > Makefile

		# Build the executable
		make clean
		make
		cp "minivmac.exe" "../${executable_path}"
		cd ../

	else

		print "Using existing executable…"

	fi

	# Copy resources
	mkdir -p "${base_path}"
	mkdir -p "${resources_path}"
	cp "${executable_path}" "${resources_path}/Mini vMac.exe"
	cp "${files_path}/vMac.ROM" "${resources_path}/vMac.ROM"
	cp "${files_path}/${file_base}.dsk" "${resources_path}/disk1.dsk"

	# Create a shortcut to the exe. This is a pre-made shortcut that uses a
	# relative path: %COMSPEC% /C "start /b .\Resources\^"Mini vMac.exe^""
	cp "${files_path}/shortcut.lnk" "${base_path}/${app_name}.lnk"

	# Create a bat file that launches the exe, an alternative to the shortcut
	# echo "@echo off\r\nstart /b .\Resources\\\"Mini vMac.exe\"" > \
	#	"${base_path}/${app_name}.bat"

	# Zip the files
	cd "${build_path}"
	rm -f "${zip_name}"
	zip -r "${zip_name}" "${app_name}" -x "**/.DS_Store" "**/__MACOSX"
	rm -rf "${app_name}"

	print "Done"
	success=true

fi

if [[ $platform == "dsk" ]]
then

	print "Building disk image version…"

	local zip_path="../${build_path}/${file_base}.dsk.zip"

	# Zip the files
	cd "${files_path}"
	rm -f "${zip_path}"
	zip "${zip_path}" "${file_base}.dsk"
	if [[ ! -z $read_me ]]
	then
		zip "${zip_path}" "${read_me}"
	fi

	print "Done"
	success=true

fi

if [[ $success != true ]]
then
	echo >&2 "Unknown platform: ${platform}"
	exit 1
fi
