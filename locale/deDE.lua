local addonName = "Max_Camera_Distance"
local L = LibStub("AceLocale-3.0"):NewLocale(addonName, "deDE")

if not L then return end

-- *** General Settings ***
L["GENERAL_SETTINGS"] = "Allgemeine Einstellungen"

L["MAX_ZOOM_FACTOR"] = "Maximale Kameradistanz"
L["MAX_ZOOM_FACTOR_DESC"] = "Legt die maximal zulässige Kameradistanz fest (in Meter/Yards)."

L["MOVE_VIEW_DISTANCE"] = "Zoom-Geschwindigkeit"
L["MOVE_VIEW_DISTANCE_DESC"] = "Legt fest, wie schnell die Kamera hinein- und herauszoomt."

L["YAW_MOVE_SPEED"] = "Horizontale Drehgeschwindigkeit"
L["YAW_MOVE_SPEED_DESC"] = "Passt die Geschwindigkeit der horizontalen Kamerabewegung an (Gieren)."

L["PITCH_MOVE_SPEED"] = "Vertikale Drehgeschwindigkeit"
L["PITCH_MOVE_SPEED_DESC"] = "Passt die Geschwindigkeit der vertikalen Kamerabewegung an (Neigen)."

-- *** Combat Settings ***
L["COMBAT_SETTINGS"] = "Intelligenter Kampf-Zoom"
L["COMBAT_SETTINGS_WARNING"] = "|cff0070deDieser Bereich ermöglicht es der Kamera, die Distanz automatisch zu ändern, je nachdem, ob du dich im Kampf befindest oder nicht.|r"

L["AUTO_ZOOM_COMBAT"] = "Intelligenten Kampf-Zoom aktivieren"
L["AUTO_ZOOM_COMBAT_DESC"] = "Wenn aktiviert, zoomt die Kamera bei Kampfbeginn automatisch heraus und nach Kampfende wieder hinein."

L["MAX_COMBAT_ZOOM_FACTOR"] = "Distanz im Kampf"
L["MAX_COMBAT_ZOOM_FACTOR_DESC"] = "Die gewünschte Kameradistanz, während du dich IM KAMPF befindest."

L["MIN_COMBAT_ZOOM_FACTOR"] = "Distanz außerhalb des Kampfes"
L["MIN_COMBAT_ZOOM_FACTOR_DESC"] = "Die gewünschte Kameradistanz, wenn du dich NICHT im Kampf befindest (Ruhemodus)."

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
L["SETTINGS_SET_TO_MAX"] = "Kameraeinstellungen auf Maximum gesetzt."
L["SETTINGS_SET_TO_AVERAGE"] = "Kameraeinstellungen auf Durchschnitt gesetzt."
L["SETTINGS_SET_TO_MIN"] = "Kameraeinstellungen auf Minimum gesetzt."
L["SETTINGS_SET_TO_DEFAULT"] = "Kameraeinstellungen auf Standardwerte zurückgesetzt."
L["SETTINGS_RESET"] = "Profil wurde auf Standardwerte zurückgesetzt."

L["WARNING_TEXT"] = "Dieses Addon erweitert das Limit der Kameradistanz, um die Übersicht in Raids, Dungeons und PvP zu verbessern."

L["RELOAD_BUTTON"] = "UI neu laden"
L["RELOAD_BUTTON_DESC"] = "Lädt das Benutzerinterface neu, um kritische Änderungen anzuwenden."

L["RESET_BUTTON"] = "Standardwerte"
L["RESET_BUTTON_DESC"] = "Setzt alle Einstellungen in diesem Profil auf die Standardwerte zurück."

-- *** Debug Settings ***
L["DEBUG_SETTINGS"] = "Debug-Einstellungen"
L["ENABLE_DEBUG_LOGGING"] = "Logging aktivieren"
L["ENABLE_DEBUG_LOGGING_DESC"] = "Gibt Debug-Informationen im Chatfenster aus."

L["DEBUG_LEVEL"] = "Debug-Level"
L["DEBUG_LEVEL_DESC"] = "Wähle die Ausführlichkeit der Protokolle."
L["DEBUG_LEVEL_ERROR"] = "Fehler"
L["DEBUG_LEVEL_WARNING"] = "Warnung"
L["DEBUG_LEVEL_INFO"] = "Info"
L["DEBUG_LEVEL_DEBUG"] = "Ausführlich"