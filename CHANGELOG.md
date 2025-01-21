#### release 5.1 (HOTFIX)

- fix: Handle CVAR updates in OnCVarUpdate function
  - Added cvarHandlers table for centralized CVAR update handling.
  - Simplified OnCVarUpdate function code.

#### release 5.0

- Implemented automatic camera zoom adjustments:
  - Max zoom during combat and min zoom after combat with configurable delay

- Code cleanup:
  - Encapsulated camera adjustment logic in reusable functions.
  - Improved error handling with `SafeCall`.
  - Refined event registration and handling for reliability.
