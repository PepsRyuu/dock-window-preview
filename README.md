# Dock Window Preview

Adds window preview functionality for Mac Dock, an open-source alternative to HyperDock / DockView.

I've recently had to start using a Macbook for work, and it's been very difficult to multi-task effectively without the window management features that Windows provide. AltTab and Rectangle are great to provide visual tabbing and snapping, but there doesn't appear to be an open-source option for adding previews to the dock. While there is HyperDock and DockView, they are paid closed-source applications for what should be a relatively simple feature. Also due to the closed source nature of them, there has been issues with their development. This project aims to be an open-source alternative so anyone can use this for free and customise as needed.

This is still very early in development with a long way to go.

## Notes

* My knowledge of Objective-C and the Mac SDK is very limited. There's probably better ways of approaching things.
* Working in JavaScript allows me to quickly prototype new ideas, and it makes contributions for others easier.
* Terminal needs both Screen Recording and Accessibility privileges. This is dangerous but it's temporary for initial development.

## TODO

* Don't hide the preview when moving away from the dock icon.
* Keep aspect ratio of images correct.
* Allow to click on image to show that window.
* Ability to close and minimize windows from preview
* Keyboard controls.
* Multiple monitors.
* Hide from the Dock this app.
* Apply GPLv3 license.
* Permissions management. Avoid terminal using these permissions.
* App packaging.