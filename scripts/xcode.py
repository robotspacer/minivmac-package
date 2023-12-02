#!/usr/bin/python3

from argparse import ArgumentParser
from pbxproj import XcodeProject
import subprocess
import re

# MARK: Parse arguments

parser = ArgumentParser()
parser.add_argument('-p', '--project', dest='project', required=True,
	help='The path to the pbxproj file: example.xcodeproj/project.pbxproj')
parser.add_argument('-i', '--info', dest='info', required=True,
	help='The path to the Info.plist file: cfg/Info.plist')
parser.add_argument('-d', '--bundleid', dest='bundleid', required=True,
	help='The bundle ID')
parser.add_argument('-n', '--name', dest='name', required=True,
	help='The app name')
parser.add_argument('-b', '--build', dest='build', required=True,
	help='The build version string')
parser.add_argument('-v', '--version', dest='version', required=True,
	help='The marketing version string')
args = parser.parse_args()

# MARK: Update Xcode project

print('Updating Xcode project…')

project = XcodeProject.load(args.project)

# There's no way to just set a new value--we have to remove all possible values
# first, then add the new value.
project.remove_flags('PRODUCT_NAME', 'minivmac')
project.add_flags('PRODUCT_NAME', args.name)

project.remove_flags('PRODUCT_BUNDLE_IDENTIFIER', 'com.gryphel.minivmac')
project.add_flags('PRODUCT_BUNDLE_IDENTIFIER', args.bundleid)

# This works but it seems to require a full path, and there's no way to add the
# folder to the correct location, so it's not worthwhile.
# file_options = FileOptions(create_build_files=False)
# project.add_folder('/Users/name/path/to/source/mnvm_dat',
# 	create_groups=False,
# 	file_options=file_options)

project.save()

# MARK: Update Info.plist

print('Updating Info.plist…')

result = subprocess.run(['plutil',
	'-extract', 'CFBundleGetInfoString',
	'raw', '-o', '-',
	args.info],
	capture_output=True,
	text=True)
getinfo = result.stdout

# result = re.search('minivmac[a-z0-9-.]*, Copyright [0-9]* maintained by [A-Za-z .]*', getinfo)
result = re.search('minivmac[a-z0-9-.]*', getinfo)

try:
	resultstring = result.group(0)
	getinfo = f"{args.name} {args.version} ({resultstring}, © 2023 maintained by Paul C. Pratt)"
	print(getinfo)
except AttributeError:
	raise SystemExit(f'Failed to parse Get Info string: {getinfo}')

subprocess.run(['plutil',
	'-replace', 'CFBundleExecutable',
	'-string', args.name,
	args.info])

subprocess.run(['plutil',
	'-replace', 'CFBundleIdentifier',
	'-string', args.bundleid,
	args.info])

subprocess.run(['plutil',
	'-replace', 'CFBundleName',
	'-string', args.name,
	args.info])

subprocess.run(['plutil',
	'-replace', 'CFBundleVersion',
	'-string', args.build,
	args.info])

subprocess.run(['plutil',
	'-replace', 'CFBundleShortVersionString',
	'-string', args.version,
	args.info])

subprocess.run(['plutil',
	'-replace', 'CFBundleGetInfoString',
	'-string', getinfo,
	args.info])
