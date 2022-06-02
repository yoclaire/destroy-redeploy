#!/usr/bin/env bash
#
#   ---------------------------------------------------------
#  |       eeeee eeee eeeee eeeee eeeee  eeeee e    e        |
#  |       8   8 8    8   "   8   8   8  8  88 8    8        |
#  |       8e  8 8eee 8eeee   8e  8eee8e 8   8 8eeee8        |
#  |       88  8 88      88   88  88   8 8   8   88          |
#  |       88ee8 88ee 8ee88   88  88   8 8eee8   88          |
#  |                                                         |
#  |    eeeee  eeee eeeee eeee eeeee e     eeeee e    e      |
#  |    8   8  8    8   8 8    8   8 8     8  88 8    8      |
#  |    8eee8e 8eee 8e  8 8eee 8eee8 8e    8   8 8eeee8      |
#  |    88   8 88   88  8 88   88    88    8   8   88        |
#  |    88   8 88ee 88ee8 88ee 88    88eee 8eee8   88  v1.0  |
#  |                                                         |
#  |                                                         |
#  |  ~ update MacOS applications with extreme prejudice ~   |
#  |                                                         |
#  |                   github.com/0xclaire/destroy-redeploy  |
#   ---------------------------------------------------------
#
# quit application and tie up any loose ends
osascript -e 'quit app "Google Chrome.app"'
killall "Google Chrome"
#
# change working directory
cd /Applications
#
# KILL IT WITH FIRE
rm -rf "Google Chrome.app"
#
# go back to root dir
cd ..
#
# make temp folder for downloads
mkdir "/tmp/chrome"
#
# change working directory
cd "/tmp/chrome"
#
# check if running on apple silicon or intel cpu
if [[ $(uname -m) == 'arm64' ]]; then
  echo Apple Silicon Detected
  # download latest installer dmg for apple silicon 
curl -L -o "/tmp/chrome/googlechrome.dmg" "https://dl.google.com/chrome/mac/universal/stable/CHFA/googlechrome.dmg"
elif [[ $(uname -m) == 'x86_64' ]]; then
  echo Intel CPU Detected
  # download latest installer dmg for intel-based cpu 
curl -L -o "/tmp/chrome/googlechrome.dmg" "https://dl.google.com/chrome/mac/stable/GGRO/googlechrome.dmg"
fi
#
# mount chrome disk image
hdiutil attach "/tmp/chrome/googlechrome.dmg"
#
# install chrome from disk image 
ditto -rsrc "/Volumes/Google Chrome/Google Chrome.app" "/Applications/Google Chrome.app"
#
# unmount chrome disk image
hdiutil detach "/Volumes/Google Chrome"
#
# clean out the temp dir
sudo rm -rf "/tmp/chrome"
#
# bless app
xattr -rc "/Applications/Google Chrome.app"
#