#### release 2.0

- Implemented automatic camera zoom adjustment on mounting and dismounting
- Added configuration option for autoMountZoom in settings
- Introduced localizations for new settings
- Improved code readability and ensured proper restoration of camera zoom levels
- Added a 'Reload UI' button to reload the user interface and apply new settings.
- Added a 'Reset to Default' button to reset settings to their default values.
- Included version information at the top of the options panel, showing the current version of the addon.
- Updated the localization for new button labels and descriptions.
- Completely rewrote the logic for the addon to enhance performance and responsiveness.
- Replaced the outdated camera settings tracking method with an event listener for the CVAR_UPDATE event.
- The new approach ensures that changes to camera settings are detected promptly, maintaining consistency and avoiding unnecessary updates.
