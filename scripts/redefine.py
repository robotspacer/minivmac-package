#!/usr/bin/python3

from argparse import ArgumentParser
import subprocess
import re
import os.path
import shutil

# MARK: Parse arguments

parser = ArgumentParser()
parser.add_argument('-f', '--file', dest='file', required=True,
	help='The file to update')
parser.add_argument('-k', '--key', dest='key', required=True,
	help='The key to update in the given file')
parser.add_argument('-s', '--string', dest='string', required=True,
	help='The string value to insert')
args = parser.parse_args()

# MARK: Update the file

input_path = args.file
backup_path = input_path + "-backup"
output_path = input_path + "-new"

print('Updating '+input_path+'…')

# Back up the original file if there's not a backup already
if not os.path.exists(backup_path):
	shutil.copyfile(input_path, backup_path)

# Read the file in and write out the new file
input_file = open(input_path, "r")
output_file = open(output_path, "w")

for line in input_file:
	match = re.match(r'#define '+args.key+' .*$', line)
	if match:
		new_line = '#define '+args.key+' "'+args.string+'"\n';
		output_file.write(new_line)
	else:
		output_file.write(line)

# Replace the original file with the new one
os.replace(output_path, input_path)
