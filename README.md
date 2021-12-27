# Dock Window Preview

Adds window preview functionality on hover for Mac Dock, an open-source alternative.

*This is very early in development and it will be buggy. Use at your own risk.*

![Image](./docs/image.png)

## Motivation

A long-time Windows user here, and I recently had to start using a Macbook, which has been a frustrating experience.
Thankfully, most of my needs as a Windows user are satisfied thanks to AltTab, Rectangle and Karabiner, but I noticed there didn't appear to be any viable option for window previewing on the dock.
The only options seemed to be old paid closed source applications (eg. HyperDock), with no guarantee they were going to work properly at all and didn't seem well supported.
So after a lot of research, I decided to give it a try myself and to give it away for free.

## Getting Started

* Ensure you have NodeJS installed. 
* If Node is not installed, use ```brew install nvm``` and install at least 14 using ```nvm install 14``` and ```nvm use 14```.
* Run ```npm install```, and then ```npm run build```.
* App will be compiled to ```out``` directory.
* Configure ```config.json``` with additional app aliases as required.
* Run the app.
* Open ```Security & Privacy``` and grant ```Files and Folders```, ```Accessibility``` and ```Screen Recording``` permissions.

## For developers

* For permissions, grant the same permissions to ```Terminal```.
* Use ```node index.js``` to run.
* Use ```node index.js --debug``` for additional logging information.
* For context, I mostly write front-end applications, so I prefer to work with JavaScript where possible.
* My knowledge of Objective-C is incredibly basic. There's probably better ways of accomplishing certain things.
* This approach I'm inclined to stick with, as it makes it significantly easier for other people to modify the app and contribute.

## Troubleshooting

* If you rebuild the app, force quit the app using the Activity Monitor, and wipe out the permissions entirely, then run the app again.

## Task List

* Filter out Finder windows that cause crashes.
* Show preview for minimized windows.
* Keyboard Controls.
* Nicer permissions user experience.
* MenuBar Icon for configuring.
* Minimize and close windows from the previews.
* Improve performance of rendering of thumbnails and CPU usage for mouse tracking.
* Custom theming with the config file.
* Once there's a great user experience, investigate how to contribute to brew.
* Support auto-hiding dock and dock in alternate locations.
* Ensure preview does not appear outside of the monitor's area