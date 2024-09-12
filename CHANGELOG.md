#### release 3.2

- Toc Bumps for retail
- Implemented handling to turn off logging when `enableDebugLogging` is false.
- Fixed the error where `debugLevel` was treated as a string instead of a table.
- Ensured `debugLevel` is correctly initialized as a table in `Database:InitDB()`.
- Updated `debugSettings` to properly handle `debugLevel` when `enableDebugLogging` is false.
- Added safety checks to confirm `debugLevel` is a table before accessing it.
- Implemented disabling of `debugLevel` options when `enableDebugLogging` is off.
- Added conditional disabling for `debugLevel` in `debugSettings`.
- Addressed issues with automatic camera distance changes.
- Improved handling of camera distance settings to ensure correct application of changes.

#### NOTE'S
Due to numerous issues with the automatic camera distance adjustment, the parameters for this feature have been temporarily moved to the experiments section.

