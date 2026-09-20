local addonName, ns = ...
local LibStub = _G.LibStub
ns.LocaleData = ns.LocaleData or {}
local L = {}
ns.LocaleData["deDE"] = L

local AceLocale = LibStub and LibStub("AceLocale-3.0", true)
local AceTable = AceLocale and AceLocale:NewLocale(addonName, "deDE")

-- *** General Settings ***
L["GENERAL_SETTINGS"] = "Allgemeine Einstellungen"

L["MAX_ZOOM_FACTOR"] = "Maximale Kameradistanz"
L["MAX_ZOOM_FACTOR_DESC"] = "Legt die maximal zulässige Kameradistanz fest (in Meter/Yards)."

L["MOVE_VIEW_DISTANCE"] = "Manuelle Mausrad-Zoomgeschwindigkeit"
L["MOVE_VIEW_DISTANCE_DESC"] = "Legt fest, wie schnell die Kamera mit Mausrad oder Zoom-Tasten hinein- und herauszoomt. Betrifft nur manuellen Zoom."

L["YAW_MOVE_SPEED"] = "Horizontale Drehgeschwindigkeit"
L["YAW_MOVE_SPEED_DESC"] = "Passt die Geschwindigkeit der horizontalen Kamerabewegung an (Gieren)."

L["PITCH_MOVE_SPEED"] = "Vertikale Drehgeschwindigkeit"
L["PITCH_MOVE_SPEED_DESC"] = "Passt die Geschwindigkeit der vertikalen Kamerabewegung an (Neigen)."

-- *** Combat Settings ***
L["COMBAT_SETTINGS"] = "Intelligenter Kampf-Zoom"
L["COMBAT_SETTINGS_WARNING"] = "|cffffd100Systemlogik:|r Die Kameradistanz wird automatisch an deinen Zustand angepasst.\n\n|cffffd100Priorität:|r |cffff5555Kampf|r  >  |cff66ccffReittier|r  >  |cffffffffNormalzustand|r"
L["AUTO_ZOOM_COMBAT"] = "Intelligenten Kampf-Zoom aktivieren"
L["AUTO_ZOOM_COMBAT_DESC"] = "Zoomt beim Kampfbeginn automatisch auf die konfigurierte Distanz heraus. |cffff5555Höchste Priorität.|r"
L["MAX_COMBAT_ZOOM_FACTOR"] = "Distanz im Kampf"
L["MAX_COMBAT_ZOOM_FACTOR_DESC"] = "Ziel-Kameradistanz, während du |cffff5555IM KAMPF|r bist."
L["MIN_COMBAT_ZOOM_FACTOR"] = "Distanz außerhalb des Kampfes"
L["MIN_COMBAT_ZOOM_FACTOR_DESC"] = "Ziel-Kameradistanz, wenn du |cffffffffNICHT im Kampf|r und |cff66ccffNICHT aufgesessen|r bist."
L["DISMOUNT_DELAY"] = "Verzögerung nach Kampfende"
L["DISMOUNT_DELAY_DESC"] = "Zeit in Sekunden, die nach dem Verlassen des Kampfes gewartet wird, bevor die Kamera wieder hineinzoomt."

-- *** Advanced Settings ***
L["ADVANCED_SETTINGS"] = "Erweiterte Einstellungen"

L["REDUCE_UNEXPECTED_MOVEMENT"] = "Unerwartete Bewegungen verringern"
L["REDUCE_UNEXPECTED_MOVEMENT_DESC"] = "Reduziert Kamerasprünge, wenn die Kamera mit dem Gelände oder Objekten kollidiert."

L["RESAMPLE_ALWAYS_SHARPEN"] = "Immer nachschärfen"
L["RESAMPLE_ALWAYS_SHARPEN_DESC"] = "Erzwingt einen Schärfefilter, auch wenn AMD FSR Upscale deaktiviert ist."

L["INDIRECT_VISIBILITY"] = "Kamerakollision"
L["INDIRECT_VISIBILITY_DESC"] = "Steuert, wie die Kamera mit der Umgebung interagiert (reduziert das Clipping durch Objekte)."

-- *** Messages & UI ***
L["SETTINGS_CHANGED"] = "Kameraeinstellungen wurden geändert."
L["SETTINGS_RESET"] = "Profil wurde auf Standardwerte zurückgesetzt."

L["WARNING_TEXT"] = "|cffffd100Achtung:|r Dieses Addon erweitert das Limit der Kameradistanz über den Standard-Schieberegler von Blizzard hinaus, um die Übersicht in Raids, Dungeons und PvP zu verbessern."
L["RELOAD_BUTTON"] = "UI neu laden"
L["RELOAD_BUTTON_DESC"] = "Lädt das Benutzerinterface neu, um kritische Änderungen anzuwenden."

L["RESET_BUTTON"] = "Standardwerte"
L["RESET_BUTTON_DESC"] = "Setzt alle Einstellungen in diesem Profil auf die Standardwerte zurück."

-- *** Debug Settings ***
L["ENABLE_DEBUG_LOGGING"] = "Logging aktivieren"
L["ENABLE_DEBUG_LOGGING_DESC"] = "Gibt Debug-Informationen zu Zustandswechseln |cffff5555(Kampf/Reittier/AFK)|r und CVar-Aktualisierungen im Chat aus."
L["DEBUG_LEVEL"] = "Debug-Level"
L["DEBUG_LEVEL_DESC"] = "Wähle die Ausführlichkeit der Protokolle."
L["DEBUG_LEVEL_ERROR"] = "Fehler"
L["DEBUG_LEVEL_WARNING"] = "Warnung"
L["DEBUG_LEVEL_INFO"] = "Info"
L["DEBUG_LEVEL_DEBUG"] = "Ausführlich"

L["COMBAT_HEADER"] = "Kampf"
L["ZONE_CATEGORY_PVP"] = "PvP"
L["ZONE_CATEGORY_PVE"] = "PvE"
L["ZONE_ZOOM_FACTOR"] = "Zonendistanz"
L["ZONE_ZOOM_FACTOR_DESC"] = "Ziel-Kameradistanz in aktivierten Raid-, Dungeon-, Arena-, Schlachtfeld- oder Szenario-Zonen. So kannst du außerhalb dieser Zonen eine kleinere Kampfdistanz behalten."
L["DELAY_HEADER"] = "Übergangsverzögerung"
L["ACTION_CAM_SHOULDER_IN_COMBAT_NAME"] = "Schulteransicht im Kampf"
L["ACTION_CAM_SHOULDER_IN_COMBAT_DESC"] = "Aktiviert die Schulterkamera im Kampf."
L["ACTION_CAM_SHOULDER_OUT_OF_COMBAT_NAME"] = "Schulteransicht außerhalb des Kampfes"
L["ACTION_CAM_SHOULDER_OUT_OF_COMBAT_DESC"] = "Aktiviert die Schulterkamera außerhalb des Kampfes."

L["WORLD_COMBAT_ZOOM_FACTOR"] = "Kampfdistanz in der offenen Welt"
L["WORLD_COMBAT_ZOOM_FACTOR_DESC"] = "Ziel-Kameradistanz, wenn du dich in der offenen Welt im Kampf befindest."
L["PARTY_COMBAT_ZOOM_FACTOR"] = "Kampfdistanz in Gruppe"
L["PARTY_COMBAT_ZOOM_FACTOR_DESC"] = "Ziel-Kameradistanz, wenn du dich in einer Gruppe, einem Dungeon, einer Tiefe oder ähnlichen Kleingruppeninhalten im Kampf befindest."
L["RAID_COMBAT_ZOOM_FACTOR"] = "Kampfdistanz im Schlachtzug"
L["RAID_COMBAT_ZOOM_FACTOR_DESC"] = "Ziel-Kameradistanz, wenn du dich in einem Schlachtzug oder anderen Großgruppeninhalten im Kampf befindest."
L["GROUP_COMBAT_ZOOM_FACTOR"] = "Kampfdistanz in Gruppe / Schlachtzug"
L["GROUP_COMBAT_ZOOM_FACTOR_DESC"] = "Ziel-Kameradistanz, wenn du dich in einer Gruppe, einem Dungeon, Schlachtzug oder ähnlichen Gruppeninhalten im Kampf befindest."
L["PVP_COMBAT_ZOOM_FACTOR"] = "PvP-Kampfdistanz"
L["PVP_COMBAT_ZOOM_FACTOR_DESC"] = "Ziel-Kameradistanz, wenn du dich in PvP-Inhalten im Kampf befindest."

L["PROFILES"] = "Profile"
L["PROFILES_MISSING_LIB_DESC"] = "AceDBOptions-3.0 wurde nicht gefunden, daher sind erweiterte Profiloptionen nicht verfügbar."

-- Added missing fallback keys to keep UI complete
L["VERSION_PREFIX"] = "Version: "
L["ZOOM_TRANSITION"] = "Smart-Zoom-Übergangszeit"
L["ZOOM_TRANSITION_DESC"] = "Zeit in Sekunden für automatische Übergänge des intelligenten Zooms zwischen den Kamerazuständen |cffff5555Kampf|r, |cff66ccffReittier|r, AFK, Drachenrennen und Normal. Steuert nicht den Mausrad-Zoom."
L["DB_NOT_READY"] = "Datenbank ist noch nicht initialisiert."
L["SHOW_MINIMAP_BUTTON"] = "Minikartensymbol anzeigen"
L["SHOW_MINIMAP_BUTTON_DESC"] = "Schaltet das Minikartensymbol um."
L["ENABLED"] = "|cff00ff00Aktiviert|r"
L["DISABLED"] = "|cffff0000Deaktiviert|r"
L["ZONES_HEADER"] = "Combat Zones"
L["ZONES_DESC"] = "Wähle Zonen, in denen das Addon |cff00ff00maximalen Kampf-Zoom erzwingt|r.\n|cff888888Deaktiviere einzelne Zonen für ein sanfteres Kameraverhalten.|r"
L["ZONE_PARTY"] = "Dungeons"
L["ZONE_RAID"] = "Raids"
L["ZONE_ARENA"] = "Arenas"
L["ZONE_BG"] = "Schlachtfelder"
L["ZONE_SCENARIO"] = "Szenarien / Tiefen"
L["ZONE_WORLD"] = "Kampf in der offenen Welt"
L["ZONE_WORLD_DESC"] = "Zoomt bei |cffff5555JEDEM Kampf|r in der offenen Welt heraus. |cffffd100Warnung:|r kann sich beim Questen zu aggressiv anfühlen."
L["ZONE_WORLD_BOSS"] = "Weltbosse / Ereignisse"
L["ZONE_WORLD_BOSS_DESC"] = "Zoomt nur während Bosskämpfen in der offenen Welt heraus (IsEncounterInProgress)."
L["MOUNT_SETTINGS_HEADER"] = "Reittier- & Reiseeinstellungen"
L["AUTO_MOUNT_ZOOM"] = "Automatischen Zoom beim Aufsitzen aktivieren"
L["AUTO_MOUNT_ZOOM_DESC"] = "Zoomt automatisch heraus, wenn du aufgesessen bist oder dich in Reisegestalt befindest (Druide/Schamane/Rufer). Aktiv nur |cffffffffaußerhalb des Kampfes|r."
L["MOUNT_ZOOM_FACTOR"] = "Reittierdistanz"
L["MOUNT_ZOOM_FACTOR_DESC"] = "Angestrebte Kameradistanz beim Reiten oder Reisen."
L["SMART_ZOOM_MSG"] = "Intelligenter Zoom: Zustand=%s, Ziel=%.1f Meter"
L["SMART_ZOOM_DISABLED_MSG"] = "Intelligenter Zoom ist deaktiviert. Es werden die manuellen Einstellungen für die maximale Distanz verwendet."
L["SOFT_TARGET_INTERACT"] = "Interaktionssymbole für weiche Ziele"
L["SOFT_TARGET_INTERACT_DESC"] = "Zeigt Interaktionssymbole über Objekten (Briefkästen, Kräuter, Portale, NSCs) für leichteres Anvisieren."
L["EXTRA_FEATURES"] = "Zusatzfunktionen"
L["UNTRACK_QUESTS_BUTTON"] = "Alle Quests nicht mehr verfolgen"
L["UNTRACK_QUESTS_DESC"] = "Entfernt sofort alle Quests aus der Zielverfolgung, um sie übersichtlicher zu machen."
L["QUEST_TRACKER_EMPTY"] = "Die Questverfolgung ist bereits leer."
L["QUEST_TRACKER_CLEARED"] = "Verfolgung von %d Quests beendet."
L["ACTION_CAM_HEADER"] = "Action Cam"
L["ACTION_CAM_DESC"] = "Aktiviert Blizzards verborgene ActionCam-Einstellungen für ein modernes RPG-Kameragefühl."
L["ACTION_CAM_SHOULDER_NAME"] = "Schulterperspektive"
L["ACTION_CAM_SHOULDER_DESC"] = "Versetzt die Kamera leicht zur Seite (test_cameraOverShoulder). Enthält einen intelligenten Versatz, der beim nahen Heranzoomen wieder zentriert."
L["ACTION_CAM_PITCH_NAME"] = "Dynamische Neigung"
L["ACTION_CAM_PITCH_DESC"] = "Passt den Kamerawinkel an die Bewegung an (test_cameraDynamicPitch)."
L["CONFLICT_FIX_MSG"] = "ActionCam: „Charakter zentriert halten“ wurde deaktiviert, um Kamerazittern zu vermeiden."
L["AFK_MODE_HEADER"] = "AFK Mode"
L["AFK_MODE_DESC_SAFE"] = "|cff00ff00Sicherer Modus:|r Wenn das UI ausgeblendet ist, stellt |cffffd100ESC|r es sofort wieder her und beendet den AFK-Modus."
L["AFK_MODE_ENABLE"] = "AFK-Drehung aktivieren"
L["AFK_MODE_ENABLE_DESC"] = "Automatically zooms out and rotates the camera while AFK. Hides UI for cinematic effect."
L["AFK_ENTER_MSG"] = "AFK-Modus: aktiviert (filmische Drehung)."
L["AFK_EXIT_MSG"] = "AFK-Modus: deaktiviert (Benutzeroberfläche und Kamera wiederhergestellt)."
L["ZOOM_SET_MESSAGE"] = "Zoom auf %s gesetzt (%.1f Meter)"
L["HOOK_DISABLED_BY_ADDON"] = "|cffff0000Durch MaxCameraDistance deaktiviert|r"
L["HOOK_MOUSE_SPEED_DESC"] = "Die Geschwindigkeit des Mausblicks wird getrennt (horizontal/vertikal) in den Addon-Einstellungen geregelt:"
L["HOOK_MOUSE_SPEED_PATH"] = "/mcd config -> Allgemeine Einstellungen"


L["ZONE_CONTEXT_HEADER"] = "Kontextregeln"
L["ZONE_CONTEXT_DESC"] = "Diese Schalter entscheiden, ob Kämpfe in Gruppe, Schlachtzug, Schlachtfeld, Arena und Szenario ihre eigene Vorlage verwenden oder auf die Kampfdistanz der offenen Welt zurückfallen."
L["ZONE_PARTY_DESC"] = "Verwendet die Gruppenkampfdistanz in Dungeons und Gruppeninhalten. Deaktiviert dies, um stattdessen auf die Kampfdistanz der offenen Welt zurückzufallen."
L["ZONE_RAID_DESC"] = "Verwendet die Schlachtzugskampfdistanz in Schlachtzugsinhalten. Deaktiviert dies, um stattdessen auf die Kampfdistanz der offenen Welt zurückzufallen."
L["ZONE_ARENA_DESC"] = "Verwendet die PvP-Kampfdistanz in Arenen. Deaktiviert dies, um stattdessen auf die Kampfdistanz der offenen Welt zurückzufallen."
L["ZONE_BG_DESC"] = "Verwendet die PvP-Kampfdistanz auf Schlachtfeldern. Deaktiviert dies, um stattdessen auf die Kampfdistanz der offenen Welt zurückzufallen."
L["ZONE_SCENARIO_DESC"] = "Verwendet die Gruppenkampfdistanz in Szenarien und Tiefen. Deaktiviert dies, um stattdessen auf die Kampfdistanz der offenen Welt zurückzufallen."

L["STATUS_HEADER"] = "Live Status"
L["STATUS_DESC"] = "Zeigt die aktuell ermittelte Zoomentscheidung und ihre Begründung."
L["STATUS_UNAVAILABLE"] = "Der Livestatus ist derzeit nicht verfügbar."
L["STATUS_ZOOM_STATE"] = "Zoom State"
L["STATUS_CONTEXT"] = "Ermittelter Kontext"
L["STATUS_RAW_CONTEXT"] = "Raw Context"
L["STATUS_ZONE_SOURCE"] = "Zone Source"
L["STATUS_TARGET_DISTANCE"] = "Zieldistanz"
L["STATUS_WORLD_FALLBACK"] = "Weltwert wird als Rückfall verwendet"
L["STATUS_REASON_FLAGS"] = "Reason Flags"
L["STATUS_ZONE_FLAGS"] = "Zone Flags"
L["STATUS_YES"] = "Yes"
L["STATUS_NO"] = "No"
L["STATUS_STATE_NONE"] = "None"
L["STATUS_STATE_MOUNT"] = "Mount"
L["STATUS_STATE_COMBAT"] = "Combat"
L["STATUS_CONTEXT_WORLD"] = "World"
L["STATUS_CONTEXT_PARTY"] = "Party"
L["STATUS_CONTEXT_RAID"] = "Raid"
L["STATUS_CONTEXT_PVP"] = "PvP"
L["STATUS_ZONE_SOURCE_WORLD"] = "World"
L["STATUS_ZONE_SOURCE_PARTY"] = "Party"
L["STATUS_ZONE_SOURCE_RAID"] = "Raid"
L["STATUS_ZONE_SOURCE_ARENA"] = "Arena"
L["STATUS_ZONE_SOURCE_BG"] = "Battleground"
L["STATUS_ZONE_SOURCE_SCENARIO"] = "Szenario / Tiefe"

L["STATUS_REASON_PLAYER"] = "Player"
L["STATUS_REASON_GROUP"] = "Group"
L["STATUS_REASON_THREAT"] = "Threat"
L["STATUS_REASON_MOUNTED"] = "Mounted"
L["STATUS_REASON_WORLD_BOSS"] = "World Boss"


L["PRESET_SETTINGS"] = "Presets"
L["PRESET_SECTION_HEADER"] = "Distanzvorlagen"
L["PRESET_SECTION_DESC"] = "Voreinstellungen wandeln allgemeine Auswahl in echte Distanzen um. Wenn ein anderes Preset als |cffffd100Manuell|r gewählt ist, wird der passende Schieberegler automatisch |cffff5555gesperrt|r."
L["PRESET_MANUAL_GROUP_HEADER"] = "Manuell / Normal"
L["PRESET_COMBAT_GROUP_HEADER"] = "Kampfvorlagen"
L["PRESET_MOUNT_GROUP_HEADER"] = "Reittier / Reisen"
L["PRESET_MANUAL"] = "Manual"
L["PRESET_CLIENT_DEFAULT"] = "Game Default"
L["PRESET_CLOSE"] = "Close"
L["PRESET_BALANCED"] = "Balanced"
L["PRESET_FAR"] = "Far"
L["PRESET_MAX"] = "Maximum"
L["PRESET_STATUS_UNAVAILABLE"] = "Der Vorlagenstatus ist nicht verfügbar."
L["PRESET_STATUS_MANUAL"] = "Manuelle Steuerung ist aktiv. Reglerwert: %.1f m."
L["PRESET_STATUS_LOCKED"] = "Vorlage: %s. Tatsächliche Distanz: %.1f m. Der zugehörige manuelle Regler ist gesperrt, bis Ihr zurück auf „Manuell“ wechselt."
L["PRESET_UNKNOWN"] = "Unknown"
L["MANUAL_SECTION_HEADER"] = "Manuelle Kamerasteuerung"
L["MANUAL_SECTION_DESC"] = "Manuelle Steuerungen bleiben nur verfügbar, wenn das passende Preset auf |cffffd100Manuell|r steht."
L["MANUAL_COMBAT_HEADER"] = "Manuelle Distanzen"
L["MANUAL_COMBAT_DESC"] = "Diese Regler werden nur verwendet, wenn die zugehörige Vorlage auf „Manuell“ steht."
L["MANUAL_MAX_PRESET"] = "Vorlage für maximale Distanz"
L["NORMAL_ZOOM_PRESET"] = "Vorlage für normale Distanz"
L["WORLD_COMBAT_PRESET"] = "Vorlage für Kampf in der offenen Welt"
L["PARTY_COMBAT_PRESET"] = "Vorlage für Gruppenkampf"
L["RAID_COMBAT_PRESET"] = "Vorlage für Schlachtzugskampf"
L["PVP_COMBAT_PRESET"] = "Vorlage für PvP-Kampf"
L["MOUNT_ZOOM_PRESET"] = "Vorlage für Reittierdistanz"

L["STATUS_DISTANCE_SOURCE"] = "Quelle der Distanz"


L["DEBUG_SETTINGS"] = "Status & Fehlersuche"
L["DEBUG_LOGGING_HEADER"] = "Chat Logging"
L["DEBUG_LOGGING_DESC"] = "Diese Optionen steuern, was im Chat ausgegeben wird. Der Block |cffffd100Live-Status|r oben ist auch bei deaktivierter Protokollierung immer verfügbar."
L["COMBAT_TRIGGER_HEADER"] = "Kampfauslöser"
L["COMBAT_TRIGGER_DESC"] = "Legt fest, welche Ereignisse den Kampfzoom auslösen dürfen."
L["COMBAT_TRIGGER_PLAYER"] = "Zoomen, wenn ich in den Kampf gehe"
L["COMBAT_TRIGGER_PLAYER_DESC"] = "Löst den Kampfzoom aus, wenn Euer Charakter in den Kampf geht."
L["COMBAT_TRIGGER_GROUP"] = "Zoomen, wenn Gruppe oder Schlachtzug in den Kampf geht"
L["COMBAT_TRIGGER_GROUP_DESC"] = "Löst den Kampfzoom aus, wenn Eure Gruppe oder Euer Schlachtzug kämpft, auch wenn Ihr selbst noch nicht im Kampf seid."
L["COMBAT_TRIGGER_THREAT"] = "Nur bei Bedrohung zoomen"
L["COMBAT_TRIGGER_THREAT_DESC"] = "Löst den Kampfzoom aus, sobald Ihr Bedrohung habt, auch wenn der normale Kampfstatus noch nicht gesetzt ist."
L["STATUS_TRIGGER_RULES"] = "Auslöserregeln"
L["STATUS_ACTIVE_TRIGGERS"] = "Aktive Auslöser"


L["DELAY_HEADER_DESC"] = "Das Herauszoomen im Kampf erfolgt sofort. Die Rückkehr zu |cffffffffNormal|r wird je nach Kontext verzögert, um Kameraflackern zu vermeiden."
L["WORLD_COMBAT_RETURN_DELAY"] = "Rückkehrverzögerung (offene Welt)"
L["WORLD_COMBAT_RETURN_DELAY_DESC"] = "Verzögerung, bevor nach einem Kampf in der offenen Welt zur normalen Distanz zurückgekehrt wird."
L["PARTY_COMBAT_RETURN_DELAY"] = "Rückkehrverzögerung (Gruppe)"
L["PARTY_COMBAT_RETURN_DELAY_DESC"] = "Verzögerung, bevor nach einem Gruppen- oder Dungeonkampf zur normalen Distanz zurückgekehrt wird."
L["RAID_COMBAT_RETURN_DELAY"] = "Rückkehrverzögerung (Schlachtzug)"
L["RAID_COMBAT_RETURN_DELAY_DESC"] = "Verzögerung, bevor nach einem Schlachtzugskampf zur normalen Distanz zurückgekehrt wird."
L["STATUS_RETURN_DELAYS"] = "Rückkehrverzögerungen"
L["STATUS_PENDING_RETURN"] = "Ausstehende Rückkehr"
L["STATUS_PENDING_RETURN_NONE"] = "Es steht keine verzögerte Rückkehr an."
L["STATUS_PENDING_RETURN_ACTIVE"] = "%s: %s, noch %.1f s (insgesamt %.1f s)."
L["STATUS_RETURN_KIND_COMBAT"] = "Rückkehr nach Kampf"
L["STATUS_RETURN_KIND_MOUNT"] = "Mount Return"

L["OCCLUDED_SILHOUETTE_PLAYER"] = "Silhouette bei Blockierung anzeigen"
L["OCCLUDED_SILHOUETTE_PLAYER_DESC"] = "Aktiviert Blizzards Charaktersilhouette, wenn Euer Charakter von Objekten verdeckt wird. Dies ist eine globale Client-Einstellung und gilt überall."
L["STATUS_SILHOUETTE"] = "Silhouette bei Blockierung anzeigen"
L["HOOK_SILHOUETTE_DESC"] = "Die Sichtbarkeit der Charaktersilhouette wird in den Addon-Einstellungen geregelt:"
L["HOOK_SILHOUETTE_PATH"] = "/mcd config -> Erweiterte Einstellungen -> Visuelle Hilfen"
L["HOOK_SILHOUETTE_LABEL_OBSTRUCTED"] = "Silhouette bei Blockierung anzeigen"
L["HOOK_SILHOUETTE_LABEL_OBSCURED"] = "Silhouette bei Verdeckung anzeigen"


-- *** Camera Collision ***
L["INDIRECT_OFFSET"] = "Kollisionsempfindlichkeit"
L["INDIRECT_OFFSET_DESC"] = "Steuert Blizzards verringerte Empfindlichkeit der Kamerakollision. |cff66ccff0.0|r ist das Minimum und |cffff555510.0|r das Maximum. Der Addon-Standard folgt dem Standard des aktuellen Spielclients. Höhere Werte tolerieren mehr Hindernisse, bevor die Kamera heranzoomt."
L["COLLISION_HEADER"] = "Kamerakollision"
L["COLLISION_DESC"] = "Allgemeines Verhalten der Kamerakollision. Diese Einstellungen sind |cffffd100global|r und gelten überall, nicht nur pro Kampfkontext."
L["COLLISION_SUMMARY_TEXT"] = "|cff66ccffReduzierte Kamerakollision:|r %s\n|cff66ccffKollisions-Offset:|r %s\n|cff66ccffSilhouette bei Verdeckung anzeigen:|r %s\n|cff66ccffUnerwartete Bewegungen reduzieren:|r %s\n|cff888888Diese Einstellungen sind global und gelten überall.|r"
L["VISUAL_UTILITY_HEADER"] = "Visuelle Hilfen"

-- *** Mount / Travel Mode ***
L["MOUNT_ZOOM_MODE_NAME"] = "Reittier-Zoommodus"
L["MOUNT_ZOOM_MODE_DESC"] = "Wähle, ob Automatischer Reittier-Zoom für alle Reittiere und Reisegestalten, nur für fliegende Reittiere, nur für Skyriding oder nur für Reisegestalten gelten soll."
L["MOUNT_ZOOM_MODE_ALL"] = "Alle Reittiere und Reisegestalten"
L["MOUNT_ZOOM_MODE_FLYING"] = "Nur fliegende Reittiere"
L["MOUNT_ZOOM_MODE_SKYRIDING"] = "Nur Skyriding"
L["MOUNT_ZOOM_MODE_FORMS"] = "Nur Reisegestalten"

L["DRAGON_RACE_FP_NAME"] = "Ego-Perspektive während Drachenreiten-Rennen"
L["DRAGON_RACE_FP_DESC"] = "Wechselt vorübergehend in die Ego-Perspektive, solange eine Drachenreiten-Rennaura aktiv ist, und stellt nach dem Rennen wieder die Smart-Zoom-Steuerung her."

-- *** Status ***
L["STATUS_COLLISION_ENABLED"] = "Reduzierte Kamerakollision"
L["STATUS_COLLISION_OFFSET"] = "Kollisionsempfindlichkeit"
L["STATUS_SMART_PIVOT"] = "Unerwartete Bewegungen verringern"
L["STATUS_MOUNT_MODE"] = "Reittier-Zoommodus"
L["STATUS_TRAVEL_SIGNALS"] = "Reisesignale"
L["STATUS_MOUNT_ZOOM_ACTIVE"] = "Reittier-Zoom aktiv"
L["STATUS_FLYING_MOUNT"] = "Fliegendes Reittier"
L["STATUS_SKYRIDING"] = "Skyriding"
L["STATUS_DRAGON_RACE"] = "Drachenreiten-Rennen"
L["STATUS_DRAGON_RACE_FP"] = "Rennen Ego-Perspektive"


L["AFK_HIDE_UI_NAME"] = "UI im AFK ausblenden"
L["AFK_HIDE_UI_DESC"] = "Blendet das gesamte Interface für einen cineastischen AFK-Modus aus. |cffffd100ESC|r stellt es sicher wieder her, ohne auf das Zurücksetzen des AFK-Flags zu warten."
L["AFK_ZOOM_OUT_NAME"] = "Kamera im AFK herauszoomen"
L["AFK_ZOOM_OUT_DESC"] = "Schiebt die Kamera beim Eintritt in den AFK-Modus auf die maximal verwaltete Distanz."
L["AFK_DELAY_NAME"] = "Startverzögerung"
L["AFK_DELAY_DESC"] = "Wie viele Sekunden nach dem Setzen des AFK-Status gewartet werden soll, bevor der cineastische Modus startet."
L["AFK_DIRECTION_NAME"] = "Rotationsrichtung"
L["AFK_DIRECTION_DESC"] = "Wählt die Drehrichtung der Kamera im AFK-Modus."
L["AFK_DIRECTION_LEFT"] = "Links"
L["AFK_DIRECTION_RIGHT"] = "Rechts"
L["AFK_SPEED_NAME"] = "Rotationsgeschwindigkeit"
L["AFK_SPEED_DESC"] = "Normalisierte MoveView-Geschwindigkeit für die AFK-Rotation. Kleinere Werte sorgen für ruhigere Bewegungen."
L["AFK_SKIP_MOUNTED_NAME"] = "Nicht auf Reittieren starten"
L["AFK_SKIP_MOUNTED_DESC"] = "Verhindert, dass der AFK-Modus startet, solange dein Charakter auf einem Reittier sitzt."
L["AFK_SKIP_FLYING_NAME"] = "Nicht während des Fliegens starten"
L["AFK_SKIP_FLYING_DESC"] = "Verhindert, dass der AFK-Modus startet, solange dein Charakter fliegt."
L["AFK_RESUME_AFTER_COMBAT_NAME"] = "Nach Kampf fortsetzen"
L["AFK_RESUME_AFTER_COMBAT_DESC"] = "Wenn der AFK-Modus durch Kampf unterbrochen wurde, wird er nach Kampffende erneut aktiviert, falls du noch AFK bist."
L["ZOOM_RESTORE_SETTING"] = "Zoom-Wiederherstellung"
L["ZOOM_RESTORE_SETTING_DESC"] = "Legt fest, wie Smart Zoom einen zuvor verwendeten Zoomwert wiederherstellt. |cffffd100Nie|r = immer die konfigurierten Ziele verwenden. |cffffd100Adaptiv|r = den letzten Zoom nur wiederherstellen, wenn du in den Zustand zurückkehrst, aus dem du gerade gekommen bist. |cffffd100Immer|r = immer den zuletzt gespeicherten Zoom dieses Zustands bevorzugen, wenn er innerhalb der Zustandsgrenze liegt."
L["ZOOM_RESTORE_NEVER"] = "Nie"
L["ZOOM_RESTORE_ADAPTIVE"] = "Adaptiv"
L["ZOOM_RESTORE_ALWAYS"] = "Immer"
L["RESPECT_MANUAL_STATE_ZOOM"] = "Manuellen Zoom in Smart-Zuständen respektieren"
L["RESPECT_MANUAL_STATE_ZOOM_DESC"] = "Wenn Smart Zoom für Reittier oder Kampf aktiv ist, bleibt manueller Mausrad-Zoom bis zum Zustandswechsel erhalten, statt bei jeder Aktualisierung zurückgesetzt zu werden."
L["STATUS_DYNAMIC_BEHAVIOR"] = "Dynamisches Verhalten"

L["LANGUAGE_SETTING"] = 'Addon-Sprache'
L["LANGUAGE_SETTING_DESC"] = "Wähle die Sprache des Addons. |cffffd100Client-Standard|r folgt der Sprache des Spielclients. Die Benutzeroberfläche wird nach dem Ändern dieser Option |cffff5555sofort neu geladen|r."
L["LANGUAGE_CLIENT_DEFAULT"] = 'Client-Standard'
L["ADDON_TITLE"] = 'Max Camera Distance'
L["MINIMAP_TOOLTIP_OPEN_SETTINGS"] = 'Klicken, um die Einstellungen zu öffnen'
L["SETTINGS_APPLIED_FULL"] = "|cff00ff00Angewendet|r — Distanz: %.1f |cff888888(Übergang %.2fs)|r"

-- Runtime diagnostics and slash commands
L["CMD_USAGE"] = 'Verwendung: /mcd config | autozoom | automount | status | deps | fastzoom | slowzoom | reset | debug on | debug off'
L["STATUS_STATE_AFK"] = 'AFK'
L["STATUS_STATE_DRAGONRACE_FIRST_PERSON"] = 'Drachenrennen-Egoansicht'
L["STATUS_STATE_NORMAL"] = 'Normal'
L["STATUS_STATE_MANUAL"] = 'Manuell'
L["STATUS_RUNTIME_GUARDS"] = 'Laufzeit-Schutz'
L["STATUS_ACTIONCAM_SHOULDER"] = 'ActionCam-Schulter'
L["STATUS_DYNAMIC_PITCH"] = 'Dynamische Neigung'


-- Added: PvE/PvP activity contexts and Reactive Zoom
L["CAMERA_ZOOM_SPEED"] = "Zoomgeschwindigkeit des Clients"
L["CAMERA_ZOOM_SPEED_DESC"] = "Blizzards eigene CVar cameraZoomSpeed. Der reaktive Zoom berechnet damit, wie lange ein Zoomvorgang dauern soll."
L["CONTEXT_ARENA"] = "Arena"
L["CONTEXT_ARENA_DELAY_DESC"] = "Verzögerung, bevor nach einem Arenakampf zur normalen Distanz zurückgekehrt wird."
L["CONTEXT_ARENA_DESC"] = "Distanz innerhalb von Arenen."
L["CONTEXT_BATTLEGROUND"] = "Schlachtfeld"
L["CONTEXT_BATTLEGROUND_DELAY_DESC"] = "Verzögerung, bevor nach einem Schlachtfeldkampf zur normalen Distanz zurückgekehrt wird."
L["CONTEXT_BATTLEGROUND_DESC"] = "Distanz auf Schlachtfeldern und gewerteten Schlachtfeldern."
L["CONTEXT_DUNGEON"] = "Dungeon"
L["CONTEXT_DUNGEON_DELAY_DESC"] = "Verzögerung, bevor nach einem Dungeonkampf zur normalen Distanz zurückgekehrt wird."
L["CONTEXT_DUNGEON_DESC"] = "Distanz in normalen, heroischen und mythischen Dungeons."
L["CONTEXT_GROUP_NEUTRAL"] = "Außerhalb von Aktivitäten"
L["CONTEXT_GROUP_PVE"] = "PvE-Aktivitäten"
L["CONTEXT_GROUP_PVP"] = "PvP-Aktivitäten"
L["CONTEXT_MYTHIC_PLUS"] = "Mythisch+"
L["CONTEXT_MYTHIC_PLUS_DELAY_DESC"] = "Verzögerung, bevor nach einem Kampf in Mythisch+ zur normalen Distanz zurückgekehrt wird."
L["CONTEXT_MYTHIC_PLUS_DESC"] = "Distanz während eines laufenden Mythisch+-Schlüsselsteinlaufs."
L["CONTEXT_RAID"] = "Schlachtzug"
L["CONTEXT_RAID_DELAY_DESC"] = "Verzögerung, bevor nach einem Schlachtzugskampf zur normalen Distanz zurückgekehrt wird."
L["CONTEXT_RAID_DESC"] = "Distanz in Schlachtzügen und gegen Weltbosse."
L["CONTEXT_SCENARIO"] = "Szenarien & Tiefen"
L["CONTEXT_SCENARIO_DELAY_DESC"] = "Verzögerung, bevor nach einem Kampf in einem Szenario oder einer Tiefe zur normalen Distanz zurückgekehrt wird."
L["CONTEXT_SCENARIO_DESC"] = "Distanz in Szenarien, Tiefen und anderen instanzierten Aktivitäten."
L["CONTEXT_WORLD"] = "Offene Welt"
L["CONTEXT_WORLD_DELAY_DESC"] = "Verzögerung, bevor nach einem Kampf in der offenen Welt zur normalen Distanz zurückgekehrt wird."
L["CONTEXT_WORLD_DESC"] = "Distanz im Kampf in der offenen Welt außerhalb jeder Aktivität."
L["CONTEXT_WORLD_PVP"] = "Welt-PvP"
L["CONTEXT_WORLD_PVP_DELAY_DESC"] = "Verzögerung, bevor nach einem Welt-PvP-Kampf zur normalen Distanz zurückgekehrt wird."
L["CONTEXT_WORLD_PVP_DESC"] = "Distanz im Freien, während Ihr für PvP markiert seid oder der Kriegsmodus aktiv ist."
L["REACTIVE_ZOOM"] = "Reaktiven Zoom aktivieren"
L["REACTIVE_ZOOM_ALWAYS"] = "Zusätzliche Schritte (immer)"
L["REACTIVE_ZOOM_ALWAYS_DESC"] = "Wird zu jeder Mausradrastung addiert. Erhöht dies, damit eine einzelne Rastung weiter zoomt."
L["REACTIVE_ZOOM_DESC"] = "Das Mausrad legt mehr Distanz zurück, solange Ihr weiterdreht, statt in festen Schritten zu zoomen. Basiert auf dem reaktiven Zoom von DynamicCam."
L["REACTIVE_ZOOM_EASING"] = "Zoomkurve"
L["REACTIVE_ZOOM_EASING_DESC"] = "Wie der weiche Zoom über die Zeit verteilt wird. Out-Kurven starten sofort und werden zum Ziel hin langsamer, was sich am Mausrad am direktesten anfühlt."
L["REACTIVE_ZOOM_EASING_INOUTQUAD"] = "Weich (In-Out Quad)"
L["REACTIVE_ZOOM_EASING_LINEAR"] = "Gleichmäßig (Linear)"
L["REACTIVE_ZOOM_EASING_OUTCUBIC"] = "Sehr direkt (Out Cubic)"
L["REACTIVE_ZOOM_EASING_OUTQUAD"] = "Direkt (Out Quad)"
L["REACTIVE_ZOOM_EXTRA"] = "Zusätzliche Schritte (beim Drehen)"
L["REACTIVE_ZOOM_EXTRA_DESC"] = "Wird zusätzlich addiert, wenn die Kamera noch nicht aufgeholt hat. Genau das lässt schnelles Drehen deutlich weiter zoomen als langsames Klicken."
L["REACTIVE_ZOOM_HEADER"] = "Reaktiver Zoom"
L["REACTIVE_ZOOM_MAX_TIME"] = "Maximale Zoomdauer"
L["REACTIVE_ZOOM_MAX_TIME_DESC"] = "Obergrenze dafür, wie lange ein weicher Zoom dauern darf. Niedriger wirkt schneller, höher wirkt weicher."
L["REACTIVE_ZOOM_THRESHOLD"] = "Schwelle für Drehimpuls"
L["REACTIVE_ZOOM_THRESHOLD_DESC"] = "Wie weit die Kamera zurückliegen muss, bevor die zusätzlichen Schritte greifen. Niedriger reagiert früher."
L["REACTIVE_ZOOM_TOGGLE_DESC"] = "Ersetzt die festen Zoomschritte des Clients durch einen beschleunigenden, weichen Zoom."
L["WORLD_PVP_ZOOM"] = "Welt-PvP als eigene Aktivität behandeln"
L["WORLD_PVP_ZOOM_DESC"] = "Wenn aktiv, wird im Freien bei PvP-Markierung oder aktivem Kriegsmodus die Welt-PvP-Distanz statt der Distanz für die offene Welt verwendet. Deaktiviert dies, wenn Ihr dauerhaft markiert seid und eine einzige Distanz für die offene Welt möchtet."


-- Normal Distance baseline header
L["NORMAL_DISTANCE_HEADER"] = "Normale Distanz"
L["NORMAL_DISTANCE_HEADER_DESC"] = "Die Distanz, zu der die Kamera zurückkehrt, wenn Ihr weder im Kampf noch beritten seid. Jede Aktivität unten ist eine Abweichung von diesem Grundwert."


-- Adaptive combat return delay
L["ADAPTIVE_RETURN"] = "Adaptive Rückkehrverzögerung"
L["ADAPTIVE_RETURN_DESC"] = "Solange Ihr weiter pullt, misst die Kamera die Pausen zwischen den Gegnern und wartet lange genug, um sie zu überbrücken, statt bei jedem Pull heranzuzoomen und sofort wieder heraus. Sobald Ihr aufhört, kehrt sie von selbst zu Eurer eingestellten Verzögerung zurück."
L["ADAPTIVE_RETURN_MAX"] = "Obergrenze der adaptiven Verzögerung"
L["ADAPTIVE_RETURN_MAX_DESC"] = "Der höchste Wert, auf den die adaptive Verzögerung anwachsen darf. Eure eingestellte Verzögerung je Aktivität bleibt die Untergrenze."

if AceTable then
    for key, value in pairs(L) do
        AceTable[key] = value
    end
end

-- Volumetrischer Nebel nur für WoW: Forever
L["FOREVER_FOG_HEADER"] = "WoW: Forever — Volumetrischer Nebel"
L["FOREVER_FOG_DESC"] = "Grafikoptionen nur für Forever. Standardwerte werden direkt aus dem Spielclient gelesen; Änderungen schreiben sofort die entsprechende CVar."
L["FOREVER_VOLUME_FOG"] = "Volumetrischer Nebel"
L["FOREVER_VOLUME_FOG_DESC"] = "Steuert volumeFog. 0 = aus, 1 = an. Spielstandard: %s."
L["FOREVER_VOLUME_FOG_INTERIOR"] = "Volumetrischer Nebel in Innenräumen"
L["FOREVER_VOLUME_FOG_INTERIOR_DESC"] = "Steuert volumeFogInterior. 0 = aus, 1 = an. Spielstandard: %s."
L["FOREVER_VOLUME_FOG_LEVEL"] = "Qualität des volumetrischen Nebels"
L["FOREVER_VOLUME_FOG_LEVEL_DESC"] = "Steuert volumeFogLevel. Unterstützte Werte: 0 bis 3. Spielstandard: %d."
L["FOREVER_VOLUME_FOG_LEVEL_0"] = "0 — Minimum"
L["FOREVER_VOLUME_FOG_LEVEL_1"] = "1 — Stufe 1"
L["FOREVER_VOLUME_FOG_LEVEL_2"] = "2 — Stufe 2"
L["FOREVER_VOLUME_FOG_LEVEL_3"] = "3 — Maximum"

-- Erweiterte Umgebungssteuerung nur für WoW: Forever
L["FOREVER_ENVIRONMENT_HEADER"] = "WoW: Forever — Erweiterte Umgebung"
L["FOREVER_ENVIRONMENT_DESC"] = "Direkte Bodeneffekt-CVars über die normalen Grafikregler hinaus. Der Blizzard-Regler für Bodendetails kann diese Werte überschreiben; externe Änderungen werden in das Profil übernommen, statt vom Addon bekämpft zu werden."
L["FOREVER_GROUND_EFFECT_OVERRIDE"] = "Erweiterte Bodeneffekte verwalten"
L["FOREVER_GROUND_EFFECT_OVERRIDE_DESC"] = "Standardmäßig aus. Beim ersten Aktivieren übernimmt das Addon zuerst die aktuellen Rohwerte des Clients, sodass sich die Grafik nicht sofort ändert, und verwaltet danach die drei Einstellungen unten. Beim Deaktivieren werden alle drei CVars auf die Forever-Standardwerte zurückgesetzt."
L["FOREVER_RESET_DEFAULT"] = "Zurücksetzen"
L["FOREVER_RESET_DEFAULT_DESC"] = "Setzt diese Einstellung auf den integrierten Standardwert des Forever-Clients zurück."
L["FOREVER_GROUND_EFFECT_DENSITY"] = "Bodeneffekt-Dichte"
L["FOREVER_GROUND_EFFECT_DENSITY_DESC"] = "Direktes groundEffectDensity-CVar. Bereich: 16-256. Spielstandard: %d."
L["FOREVER_GROUND_EFFECT_DIST"] = "Bodeneffekt-Distanz"
L["FOREVER_GROUND_EFFECT_DIST_DESC"] = "Direktes groundEffectDist-CVar. Bereich: 32-600. Werte über dem normalen Bodendetail-Preset erhöhen die Sichtweite von Flora und Bodendetails. Spielstandard: %d."
L["FOREVER_GROUND_EFFECT_FADE"] = "Bodeneffekt-Ausblenddistanz"
L["FOREVER_GROUND_EFFECT_FADE_DESC"] = "Direktes groundEffectFade-CVar. Praktischer Bereich hier: 0-600. Ein Wert nahe groundEffectDist reduziert frühes Ausblenden der Flora. Spielstandard: %d."

L["GAMEPAD_ACTIONCAM_DESC"] = "Action Camera is configured first in the Forever Gamepad panel; compatibility options follow it."
L["GAMEPAD_ACTIONCAM_INACTIVE"] = "|cffffcc00Action Camera pausiert, bis Enable Gamepad UI (Alpha) im Forever-Client aktiviert ist.|r"
L["GAMEPAD_ACTIONCAM_BLOCKED_CENTERED"] = "|cffff5555Action Camera wird von CameraKeepCharacterCentered blockiert. MCD deaktiviert es vor Schulterkamera/Dynamic Pitch und stellt den ursprünglichen Wert danach wieder her.|r"
L["GAMEPAD_ACTIONCAM_BLOCKED_REDUCE"] = "|cffff5555Die Schulterkamera wird von CameraReduceUnexpectedMovement blockiert. MCD deaktiviert es vor dem Schulterversatz und stellt den ursprünglichen Wert danach wieder her.|r"
L["GAMEPAD_ACTIONCAM_BLOCKED_GENERIC"] = "|cffff5555Action-Camera-Kompatibilität ist noch nicht bereit (%s). Schulter/Pitch bleiben auf null, bis die Blockierung behoben ist.|r"

L["GAMEPAD_ADVANCED_OVERRIDE_DESC"] = "API-only values start from the client's built-in defaults. Enabling management applies those defaults; disabling it restores them."

L["GAMEPAD_ACTIONCAM_COMPAT_HEADER"] = "Gamepad Compatibility"

L["GAMEPAD_ACTIONCAM_COMPAT_DESC"] = "Applied only while Action Camera requests the over-shoulder camera."
