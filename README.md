# gmic-gimp-mac
## This project aims at easing the process of using the lastest version of the amazing gmic-gimp plugin on Macs.

## How do I do it?
The process is simple. Install MacPorts, install the gmic-gimp port, and execute a shell script.

## How does it work?
In short, the script does the following:
* Make sure everything is set up, e.g., the gmic-port is installed, etc.
* Create the required directory structure
* Using otool, recusrsively determine the libraries required by gmic-gimp
* Copy all of the required files
* Use install_name_tool to add an @rpath to each file and update the paths the files use to find their dependencies

## How to do it
### Install MacPorts
Go to the [MacPorts](https://www.macports.org) and install MacPorts. This document isn't designed to serve as a MacPorts tutorial so I am relying on you to figure this out for yourself.

### Install the required ports
I installed the following ports, just to make sure I have any development libraries I need.
* gimp2
* gmic-gimp

### Execute the script
The script will do everything for you. These are the steps.
* prepare
  * Make sure `gmic-gimp` is installed via ports and exit if it isn't
  * Determine the plugin version
  * Check to see if the path `./gmic-gimp/lib/gimp/2.0/plug-ins` exists and exit if it does
  * Create the directory structure
  * `cd` to the directory structure
* process_binary
  * Copy the `gmic_gimp_qt` binary to the root of the directory structure
  * Find all of the required libraries and copy them over to their correct locations
  * Update the @rpath information for the binary
* process_platforms
  * Copy the qt5 platform libraries over
  * Find all of the required libraries and copy them over to their correct locations
* process_libraries
  * Go through the directories created and search for every library file
  * Update the @rpath information for every library file found
* compress
  * Switch to the directory you executed the script from
  * Switch to the gmic-gimp directory
  * Compress everything under that directory as `gmic-gimp-<version>-<platform>-<arch>.tgz`, e.g., `gmic-gimp-3.3.5-darwin-arm64.tgz`
 
### How do I use it?
Once the process has completed you will have a directory structure that looks like this: `./some/path/gmic-gimp/lib/gimp/2.0/plug-ins`. You will now need to go configure GIMP to use the plugin.
1) Navigate to GIMP settings
2) Expand `Folders`
3) Click `Plug-ins`
4) In the right pane, select the icon that looks like a piece of paper wit a plus sign in the top left corner
5) Open the file selector to navigate to your directory structure, drilling down to `plug-ins`. In other words, if your ran the script from ~/Desktop, you will have the structure `/Users/bob/Desktop/gmic-gimp/lib/gimp/2.0/plug-ins`. You will select that path.
6) Restart GIMP so that it can re-read the plugins.