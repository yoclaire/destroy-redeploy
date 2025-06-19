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
osascript -e 'quit app "zoom.us.app"'
killall "zoom.us"
#
# change working directory
cd /Applications
#
# KILL IT WITH FIRE
rm -rf "zoom.us.app"
#
# go back to root dir
cd ..
#
# make temp folder for downloads
mkdir "/tmp/zoomus"
#
# change working directory
cd "/tmp/zoomus"
#
# check if running on apple silicon or intel cpu
if [[ $(uname -m) == 'arm64' ]]; then
  echo Apple Silicon Detected
  # download latest installer pkg for apple silicon 
curl -L -o "/tmp/zoomus/zoomusInstallerFull.pkg" "https://zoom.us/client/latest/zoomusInstallerFull.pkg?archType=arm64"
elif [[ $(uname -m) == 'x86_64' ]]; then
  echo Intel CPU Detected
  # download latest installer pkg for intel-based cpu 
curl -L -o "/tmp/zoomus/zoomusInstallerFull.pkg" "https://zoom.us/client/latest/zoomusInstallerFull.pkg"
fi
#
# install zoom.us
sudo /usr/sbin/installer -pkg zoomusInstallerFull.pkg -target /
#
# clean out the temp dir
sudo rm -rf "/tmp/zoomus"
#
# bless app
xattr -rc "/Applications/zoom.us.app"
#