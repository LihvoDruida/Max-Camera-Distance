#### release 3.11

1. WoW 11.0.x Compatibility Update:
- Fixed the InterfaceOptionsFrame_OpenToCategory call as it was removed in version 11.0.x. Replaced it with Settings.OpenToCategory.
- Adjusted the code structure to comply with the new API changes.
- Improved code readability by adding comments and optimizing structure.

2. Bug Fixes:
- Fixed an issue with the ChangeCameraSetting method, which was causing errors due to an incorrect context.
- Added checks for method availability and added error messages when necessary.
- Corrected logic for handling Druid and Shaman forms to prevent conflicts with cooldowns.

3. Test:
-  Dismount Logic: Handle camera zoom restoration with delay #1
