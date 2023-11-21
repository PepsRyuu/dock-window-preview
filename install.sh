#!/bin/bash

set -x

# Ensure we are inside the directory where this script is running
SOURCE=$(dirname "$0")
cd $SOURCE

# Ensure we have the code for the project.
if [ -d ".git" ]; then
    echo "Inside a git directory. Proceeding."
else
    echo "Not in git directory, cloning."
    git clone https://github.com/PepsRyuu/dock-window-preview.git ~/.dock-window-preview-git
    cd ~/.dock-window-preview-git
    touch .auto-generated
    SOURCE=~/.dock-window-preview-git
fi

exportNode() {
    echo $(find . -name node | grep 'bin/node')
}

exportNpm() {
    echo $(find . -name npm-cli.js | grep 'bin/npm-cli.js')
}

# Check if Node is installed locally in the project
NODE=$(exportNode)
NPM=$(exportNpm)
echo $NODE
echo $NPM

if [ -f "$NODE" ]; then
    echo "Node installed."
else
    echo "Node not found. Installing."
    mkdir -p node
    ARCHITECTURE=$(uname -m)

    if [ $ARCHITECTURE == "x86_64" ]; then
        curl https://nodejs.org/dist/v20.9.0/node-v20.9.0-darwin-x64.tar.gz --output node.tgz 
    fi

    if [ $ARCHITECTURE == "arm64" ]; then
        curl https://nodejs.org/dist/v20.9.0/node-v20.9.0-darwin-arm64.tar.gz --output node.tgz
    fi

    tar -xzvf node.tgz -C node
    NODE=$(exportNode)
    NPM=$(exportNpm)
fi

# Install dependencies and run the build
echo "Installing dependencies and running build. This may take a while..."
PATH=$(readlink -f $(dirname $NODE)):$PATH $NODE $NPM install
PATH=$(readlink -f $(dirname $NODE)):$PATH $NODE $NPM run build

# Insert Git commit id into text file
COMMIT_ID=$(git rev-parse --short HEAD)
echo $COMMIT_ID > out/Dock\ Window\ Preview.app/Contents/Resources/commit_id

# Reset accessibility permissions if they already exist.
tccutil reset Accessibility com.pepsryuu.dock-window-preview
tccutil reset ScreenCapture com.pepsryuu.dock-window-preview

# Find existing copies of the app and kill them if they're running
echo "Killing existing process"
PID=$(ps -e | grep "Dock Window Preview" | grep -v grep | awk '{print $1}')

if [ -z $PID ]; then
    echo "App not running. Proceeding."
else
    echo "App already running. Stopping process."
    kill $PID
fi

# Copy the app over to the target directory
cp -r out/Dock\ Window\ Preview.app ~/Applications

# Clean the cloned git repository if we had to clone it
if [ -f ".auto-generated" ]; then    
    echo "Deleting auto-generated directory"
    cd ~
    rm -rf ~/.dock-window-preview-git
fi

# Show the newly installed application
open ~/Applications
