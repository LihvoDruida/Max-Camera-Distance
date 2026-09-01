#### release 7.5.1

**Fixed: settings window unavailable on some characters ("isn't registered with AceConfigRegistry")**

The addon never loaded Ace3 itself. `libs/_manifest.xml` bundled only LibCamera,
while `.pkgmeta` downloaded LibStub, AceDB, AceConfig and the rest into `libs/`
without anything ever including them. The addon therefore depended on some
*other* installed addon having already put Ace3 into LibStub.

WoW loads addons in alphabetical folder order, so whether that had happened by
the time `Config.lua` ran depended on which other addons were enabled and how
their folder names sorted against `Max_Camera_Distance`. `Config.lua` captured
`AceConfig-3.0` into a file local once, at load time, so a provider that sorted
later (WeakAuras, Plater, TomTom, Questie and so on) left it `nil` for the whole
session. `SetupOptions` then returned early **in silence**, the options table was
never registered, and the only visible symptom appeared much later, when the
minimap button or `/mcd config` called `AceConfigDialog:Open()`.

Because WoW stores the enabled-addon list **per character**, the same install
worked on most characters and failed on one. Reinstalling, deleting saved
variables and switching profiles could not fix it, and the same character name
on another realm worked fine. It was never a name conflict or a class issue.

Changes:

- `libs/_manifest.xml` now actually loads LibStub, CallbackHandler, AceConsole,
  AceLocale, AceGUI, AceConfig, AceDB, AceDBOptions, LibDataBroker and LibDBIcon.
  LibCamera is loaded last; it calls `LibStub:NewLibrary()` at file scope with no
  nil guard, so it was a second way a missing LibStub could break loading.
- Ace3 and AceDB are now resolved lazily rather than once at file-load time.
- New `PLAYER_LOGIN` handler retries initialisation. Every addon has finished
  loading by then, so a late library provider is always picked up.
- If AceDB only appears late, the temporary fallback profile store is upgraded to
  a real AceDB profile and the settings made in the meantime are carried over.
- `Config:Open()` builds the options table on demand, so opening settings can no
  longer produce a raw AceConfigRegistry error.
- `SetupOptions` no longer fails silently: it reports why settings were not built.
- `AddToBlizOptions` is guarded against running twice now that setup can retry.

**Diagnostics**

- `/mcd deps` gained two lines: `Options registered` and `Profile storage`.
  Previously every library reported "found" while the settings window still
  refused to open, because the libraries were checked at command time rather than
  at load time. Those two lines report the condition that actually matters.

**Build and CI**

- New `tools/verify_manifest.py` walks the XML manifests and fails if any
  `<Script>`/`<Include>` points at a file that is not there. A referenced but
  absent library loads as nil and fails silently at runtime, which is exactly how
  this bug reached users.
- The packaging workflow now verifies the manifests before packaging and again
  against the packaged artifact, so "library is in the zip but never loaded"
  cannot ship.
- New `check_all.sh` gate: Lua 5.1 syntax, bytecode global-leak audit, XML
  well-formedness, TOC currency, manifest references, and the probe suite.
- New `tests/probe_lateace3.lua` reproduces the late-Ace3 load order and asserts
  that registration, the profile upgrade and the settings window all recover.
  Confirmed to fail against the pre-fix code.
- Fixed the global-leak audit's `SETGLOBAL` pattern, which matched nothing and so
  had been passing on every file regardless of content.

#### release 5.4

- Toc Bumps Cata and Retail
- Fix camera distance adjustment in combat, optimize event handling and CVar updates.
