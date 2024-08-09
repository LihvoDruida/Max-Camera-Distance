#### release 1.9

- Added 'INDIRECT_VISIBILITY' as a new camera collision option to the addon configuration.
- Refactored code to ensure that each camera setting (e.g., zoom factor, move view distance, camera collision) is updated and saved independently without affecting others.
- Modified the CVar update handler to ensure that changes to individual camera settings, including the new camera collision option, are correctly reflected in the addon settings and interface.
- Added detailed slash commands for different camera settings configurations, including max, average, min, and config options.
- Revised database setup to ensure proper storage and retrieval of camera settings, including handling profile changes and resets.
