local addonName, ns = ...
ns.LocaleData = ns.LocaleData or {}
local L = {}
ns.LocaleData["frFR"] = L

local AceLocale = LibStub("AceLocale-3.0", true)
local AceTable = AceLocale and AceLocale:NewLocale(addonName, "frFR")

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
L["COMBAT_SETTINGS_WARNING"] = "|cffffd100Logique du système :|r la distance de la caméra s'ajuste automatiquement selon votre état.

|cffffd100Priorité :|r |cffff5555Combat|r  >  |cff66ccffMonture|r  >  |cffffffffNormal|r"
L["AUTO_ZOOM_COMBAT"] = "Activer le zoom de combat intelligent"
L["AUTO_ZOOM_COMBAT_DESC"] = "Éloigne automatiquement la caméra jusqu'à la distance configurée à l'entrée en combat. |cffff5555Priorité la plus élevée.|r"
L["MAX_COMBAT_ZOOM_FACTOR"] = "Distance en combat"
L["MAX_COMBAT_ZOOM_FACTOR_DESC"] = "Distance cible de la caméra lorsque vous êtes |cffff5555EN combat|r."
L["MIN_COMBAT_ZOOM_FACTOR"] = "Distance hors combat"
L["MIN_COMBAT_ZOOM_FACTOR_DESC"] = "Distance cible de la caméra lorsque vous êtes |cffffffffHORS combat|r et |cff66ccffSANS monture|r."
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
L["SETTINGS_RESET"] = "Le profil a été réinitialisé aux valeurs par défaut."

L["WARNING_TEXT"] = "|cffffd100Attention :|r cet addon étend la limite de distance de la caméra au-delà du curseur Blizzard par défaut afin d'améliorer la visibilité en raid, donjon et PvP."
L["RELOAD_BUTTON"] = "Recharger l'IU"
L["RELOAD_BUTTON_DESC"] = "Recharge l'interface utilisateur pour appliquer les changements critiques."

L["RESET_BUTTON"] = "Réinitialiser"
L["RESET_BUTTON_DESC"] = "Réinitialise tous les paramètres de ce profil à leurs valeurs par défaut."

-- *** Debug Settings ***
L["DEBUG_SETTINGS"] = "Paramètres de débogage"
L["ENABLE_DEBUG_LOGGING"] = "Activer la journalisation"
L["ENABLE_DEBUG_LOGGING_DESC"] = "Affiche dans le chat des informations de débogage sur les changements d'état |cffff5555(combat/monture/AFK)|r et les mises à jour des CVar."
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
L["PARTY_COMBAT_ZOOM_FACTOR"] = "Distance de combat en groupe"
L["PARTY_COMBAT_ZOOM_FACTOR_DESC"] = "Distance cible de la caméra lorsque vous êtes en combat dans un groupe, un donjon, une Gouffre ou un contenu similaire en petit comité."
L["RAID_COMBAT_ZOOM_FACTOR"] = "Distance de combat en raid"
L["RAID_COMBAT_ZOOM_FACTOR_DESC"] = "Distance cible de la caméra lorsque vous êtes en combat dans un raid ou un autre contenu en grand groupe."
L["GROUP_COMBAT_ZOOM_FACTOR"] = "Distance de combat en groupe / raid"
L["GROUP_COMBAT_ZOOM_FACTOR_DESC"] = "Distance cible de la caméra lorsque vous êtes en combat dans un groupe, un donjon, un raid ou un contenu similaire."
L["PVP_COMBAT_ZOOM_FACTOR"] = "Distance de combat JcJ"
L["PVP_COMBAT_ZOOM_FACTOR_DESC"] = "Distance cible de la caméra lorsque vous êtes en combat dans un contenu JcJ."

L["PROFILES"] = "Profils"
L["PROFILES_MISSING_LIB_DESC"] = "AceDBOptions-3.0 est introuvable, donc les contrôles avancés de profil ne sont pas disponibles."

-- Added missing fallback keys to keep UI complete
L["VERSION_PREFIX"] = "Version: "
L["ZOOM_TRANSITION"] = "Transition Smoothness"
L["ZOOM_TRANSITION_DESC"] = "Temps en secondes pour une transition fluide entre les distances de caméra |cffff5555(combat)|r, |cff66ccffmonture|r et |cffffffffnormale|r. Des valeurs plus élevées donnent un mouvement plus lent et plus fluide."
L["DB_NOT_READY"] = "Database not initialized yet."
L["SHOW_MINIMAP_BUTTON"] = "Show Minimap Button"
L["SHOW_MINIMAP_BUTTON_DESC"] = "Toggles the minimap icon."
L["ENABLED"] = "|cff00ff00Enabled|r"
L["DISABLED"] = "|cffff0000Disabled|r"
L["ZONES_HEADER"] = "Combat Zones"
L["ZONES_DESC"] = "Sélectionnez les zones où l'addon |cff00ff00forcera le zoom de combat maximal|r.
|cff888888Désactivez certaines zones pour un comportement de caméra plus souple.|r"
L["ZONE_PARTY"] = "Dungeons"
L["ZONE_RAID"] = "Raids"
L["ZONE_ARENA"] = "Arenas"
L["ZONE_BG"] = "Battlegrounds"
L["ZONE_SCENARIO"] = "Scenarios / Delves"
L["ZONE_WORLD"] = "Open World Combat"
L["ZONE_WORLD_DESC"] = "Éloigne la caméra pour |cffff5555TOUT combat|r en monde ouvert. |cffffd100Avertissement :|r cela peut sembler trop agressif en quête."
L["ZONE_WORLD_BOSS"] = "World Bosses / Events"
L["ZONE_WORLD_BOSS_DESC"] = "Zooms out only during boss encounters in the open world (IsEncounterInProgress)."
L["MOUNT_SETTINGS_HEADER"] = "Mount & Travel Settings"
L["AUTO_MOUNT_ZOOM"] = "Enable Auto Zoom on Mount"
L["AUTO_MOUNT_ZOOM_DESC"] = "Éloigne automatiquement la caméra lorsque vous êtes sur une monture ou en forme de voyage (Druide/Chaman/Évocateur). Actif uniquement |cffffffffhors combat|r."
L["MOUNT_ZOOM_FACTOR"] = "Mount Distance"
L["MOUNT_ZOOM_FACTOR_DESC"] = "Target camera distance while mounted/traveling."
L["SMART_ZOOM_MSG"] = "Smart Zoom: state=%s, target=%.1f yards"
L["SMART_ZOOM_DISABLED_MSG"] = "Smart Zoom is disabled. Using manual max distance settings."
L["SOFT_TARGET_INTERACT"] = "Soft Target Interact Icons"
L["SOFT_TARGET_INTERACT_DESC"] = "Displays interaction icons over game objects (mailboxes, herbs, portals, NPCs) for easier targeting."
L["EXTRA_FEATURES"] = "Extra Features"
L["UNTRACK_QUESTS_BUTTON"] = "Untrack All Quests"
L["UNTRACK_QUESTS_DESC"] = "Instantly removes all quests from the objective tracker to reduce clutter."
L["QUEST_TRACKER_EMPTY"] = "Quest tracker is already empty."
L["QUEST_TRACKER_CLEARED"] = "Stopped tracking %d quests."
L["ACTION_CAM_HEADER"] = "Action Cam"
L["ACTION_CAM_DESC"] = "Enables Blizzard's hidden ActionCam settings for a modern RPG camera feel."
L["ACTION_CAM_SHOULDER_NAME"] = "Over-Shoulder View"
L["ACTION_CAM_SHOULDER_DESC"] = "Offsets the camera slightly to the side (test_cameraOverShoulder). Includes Smart Offset that recenters when zooming in close."
L["ACTION_CAM_PITCH_NAME"] = "Dynamic Pitch"
L["ACTION_CAM_PITCH_DESC"] = "Adjusts camera angle based on movement (test_cameraDynamicPitch)."
L["CONFLICT_FIX_MSG"] = "ActionCam: Disabled 'Keep Character Centered' to prevent camera jitter."
L["AFK_MODE_HEADER"] = "AFK Mode"
L["AFK_MODE_DESC_SAFE"] = "|cff00ff00Mode sûr :|r si l'interface est masquée, appuyer sur |cffffd100Échap|r la restaure immédiatement et quitte le mode AFK."
L["AFK_MODE_ENABLE"] = "Enable AFK Rotation"
L["AFK_MODE_ENABLE_DESC"] = "Automatically zooms out and rotates the camera while AFK. Hides UI for cinematic effect."
L["AFK_ENTER_MSG"] = "AFK Mode: enabled (cinematic rotation)."
L["AFK_EXIT_MSG"] = "AFK Mode: disabled (restored UI and camera)."
L["CMD_USAGE"] = "Usage: /mcd config | autozoom | automount"
L["ZOOM_SET_MESSAGE"] = "Zoom set to %s (%.1f yards)"
L["HOOK_DISABLED_BY_ADDON"] = "|cffff0000Désactivé par MaxCameraDistance|r"
L["HOOK_MOUSE_SPEED_DESC"] = "Mouse look speed is controlled separately (Horizontal/Vertical) in the addon settings:"
L["HOOK_MOUSE_SPEED_PATH"] = "/mcd config -> General Settings"


L["ZONE_CONTEXT_HEADER"] = "Context Rules"
L["ZONE_CONTEXT_DESC"] = "These toggles decide whether party, raid, battleground, arena, and scenario combat should use their own preset or fall back to the open-world combat distance."
L["ZONE_PARTY_DESC"] = "Use the Party Combat Distance in dungeon and party content. Disable it to fall back to the Open World Combat Distance instead."
L["ZONE_RAID_DESC"] = "Use the Raid Combat Distance in raid content. Disable it to fall back to the Open World Combat Distance instead."
L["ZONE_ARENA_DESC"] = "Use the PvP Combat Distance in arenas. Disable it to fall back to the Open World Combat Distance instead."
L["ZONE_BG_DESC"] = "Use the PvP Combat Distance in battlegrounds. Disable it to fall back to the Open World Combat Distance instead."
L["ZONE_SCENARIO_DESC"] = "Use the Party Combat Distance in scenarios and delves. Disable it to fall back to the Open World Combat Distance instead."

L["STATUS_HEADER"] = "Live Status"
L["STATUS_DESC"] = "Shows the current resolved zoom decision and why it was chosen."
L["STATUS_UNAVAILABLE"] = "Live status is unavailable right now."
L["STATUS_ZOOM_STATE"] = "Zoom State"
L["STATUS_CONTEXT"] = "Resolved Context"
L["STATUS_RAW_CONTEXT"] = "Raw Context"
L["STATUS_ZONE_SOURCE"] = "Zone Source"
L["STATUS_TARGET_DISTANCE"] = "Target Distance"
L["STATUS_WORLD_FALLBACK"] = "Using World Fallback"
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
L["STATUS_ZONE_SOURCE_SCENARIO"] = "Scenario / Delve"

L["STATUS_REASON_PLAYER"] = "Player"
L["STATUS_REASON_GROUP"] = "Group"
L["STATUS_REASON_THREAT"] = "Threat"
L["STATUS_REASON_MOUNTED"] = "Mounted"
L["STATUS_REASON_WORLD_BOSS"] = "World Boss"


L["PRESET_SETTINGS"] = "Presets"
L["PRESET_SECTION_HEADER"] = "Distance Presets"
L["PRESET_SECTION_DESC"] = "Les préréglages convertissent des choix de haut niveau en distances réelles. Si un préréglage autre que |cffffd100Manuel|r est sélectionné, le curseur correspondant est automatiquement |cffff5555verrouillé|r."
L["PRESET_MANUAL_GROUP_HEADER"] = "Manual / Normal"
L["PRESET_COMBAT_GROUP_HEADER"] = "Combat Presets"
L["PRESET_MOUNT_GROUP_HEADER"] = "Mount / Travel"
L["PRESET_MANUAL"] = "Manual"
L["PRESET_CLIENT_DEFAULT"] = "Game Default"
L["PRESET_CLOSE"] = "Close"
L["PRESET_BALANCED"] = "Balanced"
L["PRESET_FAR"] = "Far"
L["PRESET_MAX"] = "Maximum"
L["PRESET_STATUS_UNAVAILABLE"] = "Preset status is unavailable."
L["PRESET_STATUS_MANUAL"] = "Manual control is active. Slider value: %.1f yd."
L["PRESET_STATUS_LOCKED"] = "Preset: %s. Effective distance: %.1f yd. Matching manual control is locked until you switch back to Manual."
L["PRESET_UNKNOWN"] = "Unknown"
L["MANUAL_SECTION_HEADER"] = "Manual Camera Controls"
L["MANUAL_SECTION_DESC"] = "Les contrôles manuels restent disponibles uniquement lorsque le préréglage correspondant est défini sur |cffffd100Manuel|r."
L["MANUAL_COMBAT_HEADER"] = "Manual Distances"
L["MANUAL_COMBAT_DESC"] = "These sliders are used only when their matching preset is set to Manual."
L["MANUAL_MAX_PRESET"] = "Manual Max Distance Preset"
L["NORMAL_ZOOM_PRESET"] = "Normal Distance Preset"
L["WORLD_COMBAT_PRESET"] = "Open World Combat Preset"
L["PARTY_COMBAT_PRESET"] = "Party Combat Preset"
L["RAID_COMBAT_PRESET"] = "Raid Combat Preset"
L["PVP_COMBAT_PRESET"] = "PvP Combat Preset"
L["MOUNT_ZOOM_PRESET"] = "Mount Distance Preset"

L["STATUS_DISTANCE_SOURCE"] = "Distance Source"


L["DEBUG_SETTINGS"] = "Status & Debug"
L["DEBUG_LOGGING_HEADER"] = "Chat Logging"
L["DEBUG_LOGGING_DESC"] = "Ces options contrôlent ce qui est affiché dans le chat. Le bloc |cffffd100Statut en direct|r ci-dessus reste toujours disponible même si la journalisation est désactivée."
L["COMBAT_TRIGGER_HEADER"] = "Combat Triggers"
L["COMBAT_TRIGGER_DESC"] = "Choose which events are allowed to activate combat zoom."
L["COMBAT_TRIGGER_PLAYER"] = "Zoom when I enter combat"
L["COMBAT_TRIGGER_PLAYER_DESC"] = "Triggers combat zoom when your character enters combat."
L["COMBAT_TRIGGER_GROUP"] = "Zoom when party or raid enters combat"
L["COMBAT_TRIGGER_GROUP_DESC"] = "Triggers combat zoom when your party or raid is fighting, even if you are not actively in combat yet."
L["COMBAT_TRIGGER_THREAT"] = "Zoom on threat only"
L["COMBAT_TRIGGER_THREAT_DESC"] = "Triggers combat zoom when you have threat, even if the normal combat flag has not settled yet."
L["STATUS_TRIGGER_RULES"] = "Trigger Rules"
L["STATUS_ACTIVE_TRIGGERS"] = "Active Triggers"


L["DELAY_HEADER_DESC"] = "L'éloignement en combat est instantané. Le retour à |cffffffffNormal|r est retardé selon le contexte afin d'éviter les saccades de caméra."
L["WORLD_COMBAT_RETURN_DELAY"] = "Open World Return Delay"
L["WORLD_COMBAT_RETURN_DELAY_DESC"] = "Delay before returning to Normal after open-world combat ends."
L["PARTY_COMBAT_RETURN_DELAY"] = "Party Return Delay"
L["PARTY_COMBAT_RETURN_DELAY_DESC"] = "Delay before returning to Normal after party or dungeon combat ends."
L["RAID_COMBAT_RETURN_DELAY"] = "Raid Return Delay"
L["RAID_COMBAT_RETURN_DELAY_DESC"] = "Delay before returning to Normal after raid combat ends."
L["STATUS_RETURN_DELAYS"] = "Return Delays"
L["STATUS_PENDING_RETURN"] = "Pending Return"
L["STATUS_PENDING_RETURN_NONE"] = "No delayed return is pending."
L["STATUS_PENDING_RETURN_ACTIVE"] = "%s: %s, %.1fs remaining (total %.1fs)."
L["STATUS_RETURN_KIND_COMBAT"] = "Combat Return"
L["STATUS_RETURN_KIND_MOUNT"] = "Mount Return"

L["OCCLUDED_SILHOUETTE_PLAYER"] = "Show Silhouette when Obstructed"
L["OCCLUDED_SILHOUETTE_PLAYER_DESC"] = "Turns on Blizzard's character silhouette when your player is blocked by objects. This is a global client setting and applies everywhere."
L["STATUS_SILHOUETTE"] = "Show Silhouette when Obstructed"
L["HOOK_SILHOUETTE_DESC"] = "Character silhouette visibility is controlled in the addon settings:"
L["HOOK_SILHOUETTE_PATH"] = "/mcd config -> Advanced Settings -> Visual Utility"
L["HOOK_SILHOUETTE_LABEL_OBSTRUCTED"] = "Show Silhouette when Obstructed"
L["HOOK_SILHOUETTE_LABEL_OBSCURED"] = "Show Silhouette when Obscured"


-- *** Collision caméra ***
L["INDIRECT_OFFSET"] = "Sensibilité de collision"
L["INDIRECT_OFFSET_DESC"] = "Contrôle la sensibilité réduite de collision caméra de Blizzard. |cff66ccff0.0|r est le minimum, |cffff555510.0|r le maximum, et la valeur par défaut du jeu est |cffffd1001.5|r. Des valeurs plus élevées tolèrent davantage d'obstruction avant que la caméra ne se rapproche."
L["COLLISION_HEADER"] = "Collision de la caméra"
L["COLLISION_DESC"] = "Comportement général de collision de la caméra. Ces réglages sont |cffffd100globaux|r et s'appliquent partout, pas seulement selon le contexte de combat."
L["COLLISION_SUMMARY_TEXT"] = "|cff66ccffCollision caméra réduite :|r %s
|cff66ccffSensibilité de collision :|r %s
|cff66ccffAfficher la silhouette en cas d'obstruction :|r %s
|cff66ccffRéduire les mouvements inattendus :|r %s
|cff888888Ces réglages sont globaux et s'appliquent partout.|r"
L["VISUAL_UTILITY_HEADER"] = "Assistance visuelle"

-- *** Mode monture / voyage ***
L["MOUNT_ZOOM_MODE_NAME"] = "Mode de zoom des montures"
L["MOUNT_ZOOM_MODE_DESC"] = "Choisissez si le zoom automatique des montures doit s'appliquer à toutes les montures et formes de voyage, uniquement aux montures volantes, uniquement au Skyriding, ou uniquement aux formes de voyage."
L["MOUNT_ZOOM_MODE_ALL"] = "Toutes les montures et formes de voyage"
L["MOUNT_ZOOM_MODE_FLYING"] = "Montures volantes uniquement"
L["MOUNT_ZOOM_MODE_SKYRIDING"] = "Skyriding uniquement"
L["MOUNT_ZOOM_MODE_FORMS"] = "Formes de voyage uniquement"

L["DRAGON_RACE_FP_NAME"] = "Vue à la première personne pendant les courses de Skyriding"
L["DRAGON_RACE_FP_DESC"] = "Bascule temporairement en vue à la première personne lorsqu'une aura de course de Skyriding est active, puis restaure le contrôle du zoom intelligent à la fin de la course."

-- *** Statut ***
L["STATUS_COLLISION_ENABLED"] = "Collision caméra réduite"
L["STATUS_COLLISION_OFFSET"] = "Sensibilité de collision"
L["STATUS_SMART_PIVOT"] = "Réduire les mouvements inattendus"
L["STATUS_MOUNT_MODE"] = "Mode de zoom des montures"
L["STATUS_TRAVEL_SIGNALS"] = "Signaux de déplacement"
L["STATUS_MOUNT_ZOOM_ACTIVE"] = "Zoom de monture actif"
L["STATUS_FLYING_MOUNT"] = "Monture volante"
L["STATUS_SKYRIDING"] = "Skyriding"
L["STATUS_DRAGON_RACE"] = "Course de Skyriding"
L["STATUS_DRAGON_RACE_FP"] = "Course en première personne"


L["AFK_HIDE_UI_NAME"] = "Masquer l'interface en AFK"
L["AFK_HIDE_UI_DESC"] = "Masque toute l'interface pour un mode AFK cinématique. |cffffd100Échap|r la restaure en toute sécurité sans attendre la réinitialisation du statut AFK."
L["AFK_ZOOM_OUT_NAME"] = "Dézoomer la caméra en AFK"
L["AFK_ZOOM_OUT_DESC"] = "Pousse la caméra à la distance maximale gérée lors de l'entrée en mode AFK."
L["AFK_DELAY_NAME"] = "Délai de démarrage"
L["AFK_DELAY_DESC"] = "Nombre de secondes à attendre après l'activation du statut AFK avant de lancer le mode cinématique."
L["AFK_DIRECTION_NAME"] = "Sens de rotation"
L["AFK_DIRECTION_DESC"] = "Choisit le sens de rotation de la caméra en mode AFK."
L["AFK_DIRECTION_LEFT"] = "Gauche"
L["AFK_DIRECTION_RIGHT"] = "Droite"
L["AFK_SPEED_NAME"] = "Vitesse de rotation"
L["AFK_SPEED_DESC"] = "Vitesse MoveView normalisée pour la rotation AFK. Des valeurs plus faibles donnent un mouvement plus doux."
L["AFK_SKIP_MOUNTED_NAME"] = "Ne pas démarrer à monture"
L["AFK_SKIP_MOUNTED_DESC"] = "Empêche le mode AFK de démarrer tant que votre personnage est monté."
L["AFK_SKIP_FLYING_NAME"] = "Ne pas démarrer en vol"
L["AFK_SKIP_FLYING_DESC"] = "Empêche le mode AFK de démarrer tant que votre personnage vole."
L["AFK_RESUME_AFTER_COMBAT_NAME"] = "Reprendre après le combat"
L["AFK_RESUME_AFTER_COMBAT_DESC"] = "Si le combat a interrompu le mode AFK, il sera réactivé après la fin du combat si vous êtes toujours AFK."
L["ZOOM_RESTORE_SETTING"] = "Comportement de restauration du zoom"
L["ZOOM_RESTORE_SETTING_DESC"] = "Définit comment Smart Zoom restaure une valeur de zoom précédemment utilisée. |cffffd100Jamais|r = toujours utiliser les cibles configurées. |cffffd100Adaptatif|r = restaurer le dernier zoom uniquement lors du retour à l'état dont vous venez. |cffffd100Toujours|r = toujours préférer le dernier zoom enregistré pour cet état s'il reste dans sa limite."
L["ZOOM_RESTORE_NEVER"] = "Jamais"
L["ZOOM_RESTORE_ADAPTIVE"] = "Adaptatif"
L["ZOOM_RESTORE_ALWAYS"] = "Toujours"
L["RESPECT_MANUAL_STATE_ZOOM"] = "Respecter le zoom manuel dans les états intelligents"
L["RESPECT_MANUAL_STATE_ZOOM_DESC"] = "Lorsque Smart Zoom est actif pour la monture ou le combat, le zoom manuel à la molette est conservé jusqu'au changement d'état au lieu d'être réinitialisé à chaque mise à jour."
L["STATUS_DYNAMIC_BEHAVIOR"] = "Comportement dynamique"

L["LANGUAGE_SETTING"] = "Langue de l'addon"
L["LANGUAGE_SETTING_DESC"] = "Choisissez la langue de l'addon. |cffffd100Langue du client|r suit la langue du jeu. L'interface est |cffff5555rechargée immédiatement|r après la modification de cette option."
L["LANGUAGE_CLIENT_DEFAULT"] = 'Langue du client'
L["ADDON_TITLE"] = 'Max Camera Distance'
L["MINIMAP_TOOLTIP_OPEN_SETTINGS"] = 'Cliquez pour ouvrir les paramètres'
L["SETTINGS_APPLIED_FULL"] = "|cff00ff00Appliqué|r — distance : %.1f |cff888888(transition %.2fs)|r"

if AceTable then
    for key, value in pairs(L) do
        AceTable[key] = value
    end
end
