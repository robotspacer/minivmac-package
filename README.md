# minivmac-package

This is a package of tools to assist in bundling classic Mac applications with [Mini vMac](https://www.gryphel.com/c/minivmac/). For modern Mac computers it creates an app bundle that includes the necessary files. For Windows computers it creates a folder with the necessary resources and a `bat` file to launch the `exe`. In both cases Mini vMac will automatically boot from the included `dsk` image.

## Setting things up

Before you run the script, you'll need to add some files:

- `files/example.config`: A configuration file with various settings used in 
  the build process. See the example file for the required settings.

- `files/example.dsk`: A bootable disk image that includes your application. 
  This can be created using a standard build of Mini vMac. The base file name
  should match the `file-base` setting in your `config` file.

- `files/example.iconset`: An `iconset` folder including images for the Mac app 
  icon. The base file name should match the `file-base` setting in your 
  `config` file. This can be created using [free templates available from 
  Apple](https://developer.apple.com/design/resources/).

- `files/vMac.ROM`: A Mac Plus ROM file.

- `files/wx64/Mini vMac.exe`: A copy of Mini vMac for Windows (64-bit). For 
  best results, use the [variations
  service](https://www.gryphel.com/c/minivmac/vart_srv.html) with these 
  settings: `-br 36 -t wx64 -magnify 1 -speed z -bg 1 -svl 1`. These settings 
  enable magnified mode by default, set the speed to 1×, and set the system 
  volume to 1.

- `source`: The [Mini vMac source 
  code](https://www.gryphel.com/c/minivmac/beta.html). To build a version for 
  Apple Silicon, this must be version 37 or later.

In addition, Mac builds require Python 3 and pbxproj:

- Install [Homebrew](https://brew.sh)
- `brew install python`
- `pip3 install pbxproj`
- `brew info python` and find the path where it says "Unversioned symlinks… 
  have been installed into"
- Using that path, add this line to `~/.zshrc`:
  `export PYTHONPATH=$PYTHONPATH:<path>`

## Building a package

Here's an example command:
`./build.sh --platform mac --config example`

Possible platforms are `mac`, `mac-x86`, or `windows`. The `config` argument
should match the base file name of your `config` file in the `files` folder.

## Thanks

I was inspired to put this together after seeing how [Sonneveld](https://twitter.com/sonneveld) bundled [The Secret of Donkey Island](https://donkeyisland.zip) with DOSBox. It's a delightful game, you should try it.
