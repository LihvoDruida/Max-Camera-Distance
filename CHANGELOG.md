#### release 5.2

- Camera zoom now reacts to entering a dungeon or raid as if the player is in combat.
- Utilized IsInInstance() to check if the player is in a party or raid instance, updating zoom behavior accordingly.
- Added check to prevent unnecessary camera zoom changes when the combat state remains the same.
- Replaced 'self:AdjustCamera()' with 'Functions:AdjustCamera()' to avoid nil reference errors.
- Improved performance by reducing redundant updates to camera settings and ensuring proper event handlers.
