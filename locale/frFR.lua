local addonName = "Max_Camera_Distance"
local L = LibStub("AceLocale-3.0"):NewLocale(addonName, "frFR")

if not L then return end

-- *** General Settings ***
L["GENERAL_SETTINGS"] = "Paramètres généraux"

L["MAX_ZOOM_FACTOR"] = "Distance max de la caméra"
L["MAX_ZOOM_FACTOR_DESC"] = "Définit la distance maximale autorisée pour la caméra (en mètres/yards)."

L["MOVE_VIEW_DISTANCE"] = "Vitesse du zoom"
L["MOVE_VIEW_DISTANCE_DESC"] = "Règle la vitesse à laquelle la caméra effectue un zoom avant ou arrière."

L["YAW_MOVE_SPEED"] = "Vitesse de rotation horizontale"
L["YAW_MOVE_SPEED_DESC"] = "Règle la vitesse du mouvement horizontal de la caméra (lacet)."

L["PITCH_MOVE_SPEED"] = "Vitesse de rotation verticale"
L["PITCH_MOVE_SPEED_DESC"] = "Règle la vitesse du mouvement vertical de la caméra (tangage)."

-- *** Combat Settings ***
L["COMBAT_SETTINGS"] = "Zoom de combat intelligent"
L["COMBAT_SETTINGS_WARNING"] = "|cff0070deCette section permet à la caméra de changer automatiquement de distance selon que vous êtes en combat ou non.|r"

L["AUTO_ZOOM_COMBAT"] = "Activer le zoom de combat intelligent"
L["AUTO_ZOOM_COMBAT_DESC"] = "Si activé, la caméra s'éloignera automatiquement en entrant en combat et se rapprochera en sortant du combat."

L["MAX_COMBAT_ZOOM_FACTOR"] = "Distance en combat"
L["MAX_COMBAT_ZOOM_FACTOR_DESC"] = "La distance cible de la caméra lorsque vous êtes EN combat."

L["MIN_COMBAT_ZOOM_FACTOR"] = "Distance hors combat"
L["MIN_COMBAT_ZOOM_FACTOR_DESC"] = "La distance cible de la caméra lorsque vous êtes HORS combat (mode repos)."

L["DISMOUNT_DELAY"] = "Délai après combat"
L["DISMOUNT_DELAY_DESC"] = "Temps d'attente (en secondes) après la fin du combat avant de rétablir la distance hors combat."

-- *** Advanced Settings ***
L["ADVANCED_SETTINGS"] = "Paramètres avancés"

L["REDUCE_UNEXPECTED_MOVEMENT"] = "Réduire les mouvements inattendus"
L["REDUCE_UNEXPECTED_MOVEMENT_DESC"] = "Réduit les sauts de caméra lorsque celle-ci entre en collision avec le terrain ou des objets."

L["RESAMPLE_ALWAYS_SHARPEN"] = "Toujours affiner (Sharpen)"
L["RESAMPLE_ALWAYS_SHARPEN_DESC"] = "Force l'application d'un filtre de netteté, même si AMD FSR Upscale est désactivé."

L["INDIRECT_VISIBILITY"] = "Collision avec le terrain"
L["INDIRECT_VISIBILITY_DESC"] = "Contrôle la façon dont la caméra interagit avec l'environnement (réduit le clipping à travers les objets)."

-- *** Messages & UI ***
L["SETTINGS_CHANGED"] = "Les paramètres de la caméra ont été modifiés."
L["SETTINGS_SET_TO_MAX"] = "Paramètres de la caméra réglés sur les valeurs maximales."
L["SETTINGS_SET_TO_AVERAGE"] = "Paramètres de la caméra réglés sur les valeurs moyennes."
L["SETTINGS_SET_TO_MIN"] = "Paramètres de la caméra réglés sur les valeurs minimales."
L["SETTINGS_SET_TO_DEFAULT"] = "Paramètres de la caméra réinitialisés aux valeurs par défaut."
L["SETTINGS_RESET"] = "Le profil a été réinitialisé aux valeurs par défaut."

L["WARNING_TEXT"] = "Cet addon étend la limite de distance de la caméra pour améliorer la visibilité lors des raids, donjons et PvP."

L["RELOAD_BUTTON"] = "Recharger l'IU"
L["RELOAD_BUTTON_DESC"] = "Recharge l'interface utilisateur pour appliquer les changements critiques."

L["RESET_BUTTON"] = "Réinitialiser"
L["RESET_BUTTON_DESC"] = "Réinitialise tous les paramètres de ce profil à leurs valeurs par défaut."

-- *** Debug Settings ***
L["DEBUG_SETTINGS"] = "Paramètres de débogage"
L["ENABLE_DEBUG_LOGGING"] = "Activer la journalisation"
L["ENABLE_DEBUG_LOGGING_DESC"] = "Affiche les informations de débogage dans la fenêtre de discussion."

L["DEBUG_LEVEL"] = "Niveau de débogage"
L["DEBUG_LEVEL_DESC"] = "Sélectionnez la verbosité des journaux."
L["DEBUG_LEVEL_ERROR"] = "Erreur"
L["DEBUG_LEVEL_WARNING"] = "Avertissement"
L["DEBUG_LEVEL_INFO"] = "Info"
L["DEBUG_LEVEL_DEBUG"] = "Verbeux"

L["COMBAT_HEADER"] = "Combat"
L["ZONE_CATEGORY_PVP"] = "JcJ"
L["ZONE_CATEGORY_PVE"] = "JcE"
L["ZONE_ZOOM_FACTOR"] = "Distance des zones"
L["ZONE_ZOOM_FACTOR_DESC"] = "Distance de caméra cible dans les raids, donjons, arènes, champs de bataille ou scénarios activés. Cela vous permet de garder une distance de combat plus faible ailleurs."
L["DELAY_HEADER"] = "Délai de transition"
L["ACTION_CAM_SHOULDER_IN_COMBAT_NAME"] = "Vue d'épaule en combat"
L["ACTION_CAM_SHOULDER_IN_COMBAT_DESC"] = "Active la caméra à l'épaule pendant le combat."
L["ACTION_CAM_SHOULDER_OUT_OF_COMBAT_NAME"] = "Vue d'épaule hors combat"
L["ACTION_CAM_SHOULDER_OUT_OF_COMBAT_DESC"] = "Active la caméra à l'épaule hors combat."

L["WORLD_COMBAT_ZOOM_FACTOR"] = "Distance de combat en monde ouvert"
L["WORLD_COMBAT_ZOOM_FACTOR_DESC"] = "Distance cible de la caméra lorsque vous êtes en combat dans le monde ouvert."
L["GROUP_COMBAT_ZOOM_FACTOR"] = "Distance de combat en groupe / raid"
L["GROUP_COMBAT_ZOOM_FACTOR_DESC"] = "Distance cible de la caméra lorsque vous êtes en combat dans un groupe, un donjon, un raid ou un contenu similaire."
L["PVP_COMBAT_ZOOM_FACTOR"] = "Distance de combat JcJ"
L["PVP_COMBAT_ZOOM_FACTOR_DESC"] = "Distance cible de la caméra lorsque vous êtes en combat dans un contenu JcJ."
