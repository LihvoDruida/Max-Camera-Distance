local addonName, ns = ...
local LibStub = _G.LibStub
ns.LocaleData = ns.LocaleData or {}
local L = {}
ns.LocaleData["frFR"] = L

local AceLocale = LibStub and LibStub("AceLocale-3.0", true)
local AceTable = AceLocale and AceLocale:NewLocale(addonName, "frFR")

-- *** General Settings ***
L["GENERAL_SETTINGS"] = "Paramètres généraux"

L["MAX_ZOOM_FACTOR"] = "Distance max de la caméra"
L["MAX_ZOOM_FACTOR_DESC"] = "Définit la distance maximale autorisée pour la caméra (en mètres/yards)."

L["MOVE_VIEW_DISTANCE"] = "Vitesse du zoom manuel à la molette"
L["MOVE_VIEW_DISTANCE_DESC"] = "Règle la vitesse du zoom avec la molette de la souris ou les raccourcis de zoom. N’affecte que le zoom manuel."

L["YAW_MOVE_SPEED"] = "Vitesse de rotation horizontale"
L["YAW_MOVE_SPEED_DESC"] = "Règle la vitesse du mouvement horizontal de la caméra (lacet)."

L["PITCH_MOVE_SPEED"] = "Vitesse de rotation verticale"
L["PITCH_MOVE_SPEED_DESC"] = "Règle la vitesse du mouvement vertical de la caméra (tangage)."

-- *** Combat Settings ***
L["COMBAT_SETTINGS"] = "Zoom de combat intelligent"
L["COMBAT_SETTINGS_WARNING"] = "|cffffd100Logique du système :|r la distance de la caméra s\'ajuste automatiquement selon votre état.\n\n|cffffd100Priorité :|r |cffff5555Combat|r  >  |cff66ccffMonture|r  >  |cffffffffNormal|r"
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
L["ZOOM_TRANSITION"] = "Durée de transition Smart Zoom"
L["ZOOM_TRANSITION_DESC"] = "Temps en secondes pour les transitions automatiques du zoom intelligent entre les états de caméra |cffff5555Combat|r, |cff66ccffMonture|r, AFK, Course de dragon et Normal. Ne contrôle pas le zoom à la molette."
L["DB_NOT_READY"] = "La base de données n'est pas encore initialisée."
L["SHOW_MINIMAP_BUTTON"] = "Afficher l'icône de minicarte"
L["SHOW_MINIMAP_BUTTON_DESC"] = "Affiche ou masque l'icône de la minicarte."
L["ENABLED"] = "|cff00ff00Activé|r"
L["DISABLED"] = "|cffff0000Désactivé|r"
L["ZONES_HEADER"] = "Combat Zones"
L["ZONES_DESC"] = "Sélectionnez les zones où l\'addon |cff00ff00forcera le zoom de combat maximal|r.\n|cff888888Désactivez certaines zones pour un comportement de caméra plus souple.|r"
L["ZONE_PARTY"] = "Dungeons"
L["ZONE_RAID"] = "Raids"
L["ZONE_ARENA"] = "Arenas"
L["ZONE_BG"] = "Champs de bataille"
L["ZONE_SCENARIO"] = "Scénarios / Gouffres"
L["ZONE_WORLD"] = "Combat en monde ouvert"
L["ZONE_WORLD_DESC"] = "Éloigne la caméra pour |cffff5555TOUT combat|r en monde ouvert. |cffffd100Avertissement :|r cela peut sembler trop agressif en quête."
L["ZONE_WORLD_BOSS"] = "Boss de monde / Événements"
L["ZONE_WORLD_BOSS_DESC"] = "Dézoome uniquement pendant les rencontres de boss en monde ouvert (IsEncounterInProgress)."
L["MOUNT_SETTINGS_HEADER"] = "Réglages de monture et de déplacement"
L["AUTO_MOUNT_ZOOM"] = "Activer le zoom automatique en monture"
L["AUTO_MOUNT_ZOOM_DESC"] = "Éloigne automatiquement la caméra lorsque vous êtes sur une monture ou en forme de voyage (Druide/Chaman/Évocateur). Actif uniquement |cffffffffhors combat|r."
L["MOUNT_ZOOM_FACTOR"] = "Distance en monture"
L["MOUNT_ZOOM_FACTOR_DESC"] = "Distance de caméra visée lorsque vous êtes en monture ou en déplacement."
L["SMART_ZOOM_MSG"] = "Zoom intelligent : état=%s, cible=%.1f mètres"
L["SMART_ZOOM_DISABLED_MSG"] = "Le zoom intelligent est désactivé. Les réglages manuels de distance maximale sont utilisés."
L["SOFT_TARGET_INTERACT"] = "Icônes d'interaction de ciblage souple"
L["SOFT_TARGET_INTERACT_DESC"] = "Affiche des icônes d'interaction au-dessus des objets (boîtes aux lettres, herbes, portails, PNJ) pour faciliter le ciblage."
L["EXTRA_FEATURES"] = "Fonctions supplémentaires"
L["UNTRACK_QUESTS_BUTTON"] = "Ne plus suivre aucune quête"
L["UNTRACK_QUESTS_DESC"] = "Retire immédiatement toutes les quêtes du suivi d'objectifs pour alléger l'affichage."
L["QUEST_TRACKER_EMPTY"] = "Le suivi de quêtes est déjà vide."
L["QUEST_TRACKER_CLEARED"] = "Suivi de %d quêtes arrêté."
L["ACTION_CAM_HEADER"] = "Action Cam"
L["ACTION_CAM_DESC"] = "Active les réglages ActionCam cachés de Blizzard pour une sensation de caméra plus proche d'un RPG moderne."
L["ACTION_CAM_SHOULDER_NAME"] = "Vue par-dessus l'épaule"
L["ACTION_CAM_SHOULDER_DESC"] = "Décale légèrement la caméra sur le côté (test_cameraOverShoulder). Inclut un décalage intelligent qui recentre la vue lors d'un zoom rapproché."
L["ACTION_CAM_PITCH_NAME"] = "Inclinaison dynamique"
L["ACTION_CAM_PITCH_DESC"] = "Ajuste l'angle de la caméra en fonction du déplacement (test_cameraDynamicPitch)."
L["CONFLICT_FIX_MSG"] = "ActionCam : « Garder le personnage centré » a été désactivé pour éviter les tremblements de caméra."
L["AFK_MODE_HEADER"] = "AFK Mode"
L["AFK_MODE_DESC_SAFE"] = "|cff00ff00Mode sûr :|r si l'interface est masquée, appuyer sur |cffffd100Échap|r la restaure immédiatement et quitte le mode AFK."
L["AFK_MODE_ENABLE"] = "Activer la rotation AFK"
L["AFK_MODE_ENABLE_DESC"] = "Automatically zooms out and rotates the camera while AFK. Hides UI for cinematic effect."
L["AFK_ENTER_MSG"] = "Mode AFK : activé (rotation cinématique)."
L["AFK_EXIT_MSG"] = "Mode AFK : désactivé (interface et caméra restaurées)."
L["ZOOM_SET_MESSAGE"] = "Zoom réglé sur %s (%.1f mètres)"
L["HOOK_DISABLED_BY_ADDON"] = "|cffff0000Désactivé par MaxCameraDistance|r"
L["HOOK_MOUSE_SPEED_DESC"] = "La vitesse de la vue à la souris se règle séparément (horizontale/verticale) dans les options de l'addon :"
L["HOOK_MOUSE_SPEED_PATH"] = "/mcd config -> Réglages généraux"


L["ZONE_CONTEXT_HEADER"] = "Règles de contexte"
L["ZONE_CONTEXT_DESC"] = "Ces options déterminent si les combats en groupe, en raid, en champ de bataille, en arène et en scénario utilisent leur propre préréglage ou reviennent à la distance de combat en monde ouvert."
L["ZONE_PARTY_DESC"] = "Utilise la distance de combat en groupe dans les donjons et le contenu de groupe. Désactivez pour revenir à la distance de combat en monde ouvert."
L["ZONE_RAID_DESC"] = "Utilise la distance de combat en raid dans le contenu de raid. Désactivez pour revenir à la distance de combat en monde ouvert."
L["ZONE_ARENA_DESC"] = "Utilise la distance de combat JcJ en arène. Désactivez pour revenir à la distance de combat en monde ouvert."
L["ZONE_BG_DESC"] = "Utilise la distance de combat JcJ en champ de bataille. Désactivez pour revenir à la distance de combat en monde ouvert."
L["ZONE_SCENARIO_DESC"] = "Utilise la distance de combat en groupe dans les scénarios et les gouffres. Désactivez pour revenir à la distance de combat en monde ouvert."

L["STATUS_HEADER"] = "Live Status"
L["STATUS_DESC"] = "Affiche la décision de zoom actuellement retenue et la raison de ce choix."
L["STATUS_UNAVAILABLE"] = "Le statut en direct est indisponible pour le moment."
L["STATUS_ZOOM_STATE"] = "Zoom State"
L["STATUS_CONTEXT"] = "Contexte déterminé"
L["STATUS_RAW_CONTEXT"] = "Raw Context"
L["STATUS_ZONE_SOURCE"] = "Zone Source"
L["STATUS_TARGET_DISTANCE"] = "Distance cible"
L["STATUS_WORLD_FALLBACK"] = "Repli sur la valeur du monde"
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
L["STATUS_ZONE_SOURCE_SCENARIO"] = "Scénario / Gouffre"

L["STATUS_REASON_PLAYER"] = "Player"
L["STATUS_REASON_GROUP"] = "Group"
L["STATUS_REASON_THREAT"] = "Threat"
L["STATUS_REASON_MOUNTED"] = "Mounted"
L["STATUS_REASON_WORLD_BOSS"] = "World Boss"


L["PRESET_SETTINGS"] = "Presets"
L["PRESET_SECTION_HEADER"] = "Préréglages de distance"
L["PRESET_SECTION_DESC"] = "Les préréglages convertissent des choix de haut niveau en distances réelles. Si un préréglage autre que |cffffd100Manuel|r est sélectionné, le curseur correspondant est automatiquement |cffff5555verrouillé|r."
L["PRESET_MANUAL_GROUP_HEADER"] = "Manuel / Normal"
L["PRESET_COMBAT_GROUP_HEADER"] = "Préréglages de combat"
L["PRESET_MOUNT_GROUP_HEADER"] = "Monture / Déplacement"
L["PRESET_MANUAL"] = "Manual"
L["PRESET_CLIENT_DEFAULT"] = "Game Default"
L["PRESET_CLOSE"] = "Close"
L["PRESET_BALANCED"] = "Balanced"
L["PRESET_FAR"] = "Far"
L["PRESET_MAX"] = "Maximum"
L["PRESET_STATUS_UNAVAILABLE"] = "Le statut du préréglage est indisponible."
L["PRESET_STATUS_MANUAL"] = "Le contrôle manuel est actif. Valeur du curseur : %.1f m."
L["PRESET_STATUS_LOCKED"] = "Préréglage : %s. Distance effective : %.1f m. Le contrôle manuel correspondant est verrouillé tant que vous ne revenez pas sur « Manuel »."
L["PRESET_UNKNOWN"] = "Unknown"
L["MANUAL_SECTION_HEADER"] = "Contrôles manuels de la caméra"
L["MANUAL_SECTION_DESC"] = "Les contrôles manuels restent disponibles uniquement lorsque le préréglage correspondant est défini sur |cffffd100Manuel|r."
L["MANUAL_COMBAT_HEADER"] = "Distances manuelles"
L["MANUAL_COMBAT_DESC"] = "Ces curseurs ne sont utilisés que lorsque le préréglage correspondant est sur « Manuel »."
L["MANUAL_MAX_PRESET"] = "Préréglage de distance maximale"
L["NORMAL_ZOOM_PRESET"] = "Préréglage de distance normale"
L["WORLD_COMBAT_PRESET"] = "Préréglage de combat en monde ouvert"
L["PARTY_COMBAT_PRESET"] = "Préréglage de combat en groupe"
L["RAID_COMBAT_PRESET"] = "Préréglage de combat en raid"
L["PVP_COMBAT_PRESET"] = "Préréglage de combat JcJ"
L["MOUNT_ZOOM_PRESET"] = "Préréglage de distance en monture"

L["STATUS_DISTANCE_SOURCE"] = "Source de la distance"


L["DEBUG_SETTINGS"] = "Statut et débogage"
L["DEBUG_LOGGING_HEADER"] = "Chat Logging"
L["DEBUG_LOGGING_DESC"] = "Ces options contrôlent ce qui est affiché dans le chat. Le bloc |cffffd100Statut en direct|r ci-dessus reste toujours disponible même si la journalisation est désactivée."
L["COMBAT_TRIGGER_HEADER"] = "Déclencheurs de combat"
L["COMBAT_TRIGGER_DESC"] = "Choisissez les événements autorisés à déclencher le zoom de combat."
L["COMBAT_TRIGGER_PLAYER"] = "Zoomer quand j'entre en combat"
L["COMBAT_TRIGGER_PLAYER_DESC"] = "Déclenche le zoom de combat lorsque votre personnage entre en combat."
L["COMBAT_TRIGGER_GROUP"] = "Zoomer quand le groupe ou le raid entre en combat"
L["COMBAT_TRIGGER_GROUP_DESC"] = "Déclenche le zoom de combat lorsque votre groupe ou votre raid combat, même si vous n'êtes pas encore engagé."
L["COMBAT_TRIGGER_THREAT"] = "Zoomer uniquement sur la menace"
L["COMBAT_TRIGGER_THREAT_DESC"] = "Déclenche le zoom de combat dès que vous avez de la menace, même si l'indicateur de combat normal n'est pas encore établi."
L["STATUS_TRIGGER_RULES"] = "Règles de déclenchement"
L["STATUS_ACTIVE_TRIGGERS"] = "Déclencheurs actifs"


L["DELAY_HEADER_DESC"] = "L'éloignement en combat est instantané. Le retour à |cffffffffNormal|r est retardé selon le contexte afin d'éviter les saccades de caméra."
L["WORLD_COMBAT_RETURN_DELAY"] = "Délai de retour (monde ouvert)"
L["WORLD_COMBAT_RETURN_DELAY_DESC"] = "Délai avant de revenir à la distance normale après un combat en monde ouvert."
L["PARTY_COMBAT_RETURN_DELAY"] = "Délai de retour (groupe)"
L["PARTY_COMBAT_RETURN_DELAY_DESC"] = "Délai avant de revenir à la distance normale après un combat en groupe ou en donjon."
L["RAID_COMBAT_RETURN_DELAY"] = "Délai de retour (raid)"
L["RAID_COMBAT_RETURN_DELAY_DESC"] = "Délai avant de revenir à la distance normale après un combat de raid."
L["STATUS_RETURN_DELAYS"] = "Délais de retour"
L["STATUS_PENDING_RETURN"] = "Retour en attente"
L["STATUS_PENDING_RETURN_NONE"] = "Aucun retour différé en attente."
L["STATUS_PENDING_RETURN_ACTIVE"] = "%s : %s, %.1f s restantes (total %.1f s)."
L["STATUS_RETURN_KIND_COMBAT"] = "Retour après combat"
L["STATUS_RETURN_KIND_MOUNT"] = "Mount Return"

L["OCCLUDED_SILHOUETTE_PLAYER"] = "Afficher la silhouette lorsqu'elle est obstruée"
L["OCCLUDED_SILHOUETTE_PLAYER_DESC"] = "Active la silhouette de personnage de Blizzard lorsque votre personnage est masqué par des objets. Il s'agit d'un réglage client global qui s'applique partout."
L["STATUS_SILHOUETTE"] = "Afficher la silhouette lorsqu'elle est obstruée"
L["HOOK_SILHOUETTE_DESC"] = "La visibilité de la silhouette du personnage se règle dans les options de l'addon :"
L["HOOK_SILHOUETTE_PATH"] = "/mcd config -> Réglages avancés -> Utilitaires visuels"
L["HOOK_SILHOUETTE_LABEL_OBSTRUCTED"] = "Afficher la silhouette lorsqu'elle est obstruée"
L["HOOK_SILHOUETTE_LABEL_OBSCURED"] = "Afficher la silhouette lorsqu'elle est masquée"


-- *** Collision caméra ***
L["INDIRECT_OFFSET"] = "Sensibilité de collision"
L["INDIRECT_OFFSET_DESC"] = "Contrôle la sensibilité réduite de collision caméra de Blizzard. |cff66ccff0.0|r est le minimum et |cffff555510.0|r le maximum. La valeur par défaut de l'addon suit celle du client de jeu actuel. Des valeurs plus élevées tolèrent davantage d'obstruction avant que la caméra ne se rapproche."
L["COLLISION_HEADER"] = "Collision de la caméra"
L["COLLISION_DESC"] = "Comportement général de collision de la caméra. Ces réglages sont |cffffd100globaux|r et s'appliquent partout, pas seulement selon le contexte de combat."
L["COLLISION_SUMMARY_TEXT"] = "|cff66ccffCollision caméra réduite :|r %s\n|cff66ccffDécalage de collision :|r %s\n|cff66ccffAfficher la silhouette en cas d\'obstruction :|r %s\n|cff66ccffRéduire les mouvements inattendus :|r %s\n|cff888888Ces réglages sont globaux et s\'appliquent partout.|r"
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

-- Runtime diagnostics and slash commands
L["CMD_USAGE"] = 'Utilisation : /mcd config | autozoom | automount | status | deps | fastzoom | slowzoom | reset | debug on | debug off'
L["STATUS_STATE_AFK"] = 'ABS'
L["STATUS_STATE_DRAGONRACE_FIRST_PERSON"] = 'Course draconique première personne'
L["STATUS_STATE_NORMAL"] = 'Normal'
L["STATUS_STATE_MANUAL"] = 'Manuel'
L["STATUS_RUNTIME_GUARDS"] = 'Protections runtime'
L["STATUS_ACTIONCAM_SHOULDER"] = 'Épaule ActionCam'
L["STATUS_DYNAMIC_PITCH"] = 'Inclinaison dynamique'


-- Added: PvE/PvP activity contexts and Reactive Zoom
L["CAMERA_ZOOM_SPEED"] = "Vitesse de zoom du client"
L["CAMERA_ZOOM_SPEED_DESC"] = "La CVar cameraZoomSpeed de Blizzard. Le zoom réactif s'en sert pour calculer la durée d'un zoom."
L["CONTEXT_ARENA"] = "Arène"
L["CONTEXT_ARENA_DELAY_DESC"] = "Délai avant de revenir à la distance normale après un combat en arène."
L["CONTEXT_ARENA_DESC"] = "Distance utilisée dans les arènes."
L["CONTEXT_BATTLEGROUND"] = "Champ de bataille"
L["CONTEXT_BATTLEGROUND_DELAY_DESC"] = "Délai avant de revenir à la distance normale après un combat en champ de bataille."
L["CONTEXT_BATTLEGROUND_DESC"] = "Distance utilisée dans les champs de bataille, y compris cotés."
L["CONTEXT_DUNGEON"] = "Donjon"
L["CONTEXT_DUNGEON_DELAY_DESC"] = "Délai avant de revenir à la distance normale après un combat en donjon."
L["CONTEXT_DUNGEON_DESC"] = "Distance utilisée dans les donjons normaux, héroïques et mythiques."
L["CONTEXT_GROUP_NEUTRAL"] = "Hors activités"
L["CONTEXT_GROUP_PVE"] = "Activités JcE"
L["CONTEXT_GROUP_PVP"] = "Activités JcJ"
L["CONTEXT_MYTHIC_PLUS"] = "Mythique+"
L["CONTEXT_MYTHIC_PLUS_DELAY_DESC"] = "Délai avant de revenir à la distance normale après un combat en Mythique+."
L["CONTEXT_MYTHIC_PLUS_DESC"] = "Distance utilisée pendant une clé mythique en cours."
L["CONTEXT_RAID"] = "Raid"
L["CONTEXT_RAID_DELAY_DESC"] = "Délai avant de revenir à la distance normale après un combat de raid."
L["CONTEXT_RAID_DESC"] = "Distance utilisée en raid et contre les boss de monde."
L["CONTEXT_SCENARIO"] = "Scénarios et gouffres"
L["CONTEXT_SCENARIO_DELAY_DESC"] = "Délai avant de revenir à la distance normale après un combat en scénario ou en gouffre."
L["CONTEXT_SCENARIO_DESC"] = "Distance utilisée dans les scénarios, les gouffres et les autres activités instanciées."
L["CONTEXT_WORLD"] = "Monde ouvert"
L["CONTEXT_WORLD_DELAY_DESC"] = "Délai avant de revenir à la distance normale après un combat en monde ouvert."
L["CONTEXT_WORLD_DESC"] = "Distance utilisée en combat dans le monde ouvert, hors de toute activité."
L["CONTEXT_WORLD_PVP"] = "JcJ en monde ouvert"
L["CONTEXT_WORLD_PVP_DELAY_DESC"] = "Délai avant de revenir à la distance normale après un combat JcJ en monde ouvert."
L["CONTEXT_WORLD_PVP_DESC"] = "Distance utilisée à l'extérieur lorsque vous êtes marqué pour le JcJ ou que le mode Guerre est actif."
L["REACTIVE_ZOOM"] = "Activer le zoom réactif"
L["REACTIVE_ZOOM_ALWAYS"] = "Pas supplémentaires (toujours)"
L["REACTIVE_ZOOM_ALWAYS_DESC"] = "Ajouté à chaque cran de molette. Augmentez cette valeur pour qu'un seul cran aille plus loin."
L["REACTIVE_ZOOM_DESC"] = "La molette parcourt plus de distance tant que vous continuez à la tourner, au lieu d'avancer par pas fixes. Inspiré du zoom réactif de DynamicCam."
L["REACTIVE_ZOOM_EASING"] = "Courbe de zoom"
L["REACTIVE_ZOOM_EASING_DESC"] = "Répartition du zoom progressif dans le temps. Les courbes Out démarrent immédiatement et ralentissent près de la cible, ce qui est le plus réactif à la molette."
L["REACTIVE_ZOOM_EASING_INOUTQUAD"] = "Fluide (In-Out Quad)"
L["REACTIVE_ZOOM_EASING_LINEAR"] = "Constant (linéaire)"
L["REACTIVE_ZOOM_EASING_OUTCUBIC"] = "Très réactif (Out Cubic)"
L["REACTIVE_ZOOM_EASING_OUTQUAD"] = "Réactif (Out Quad)"
L["REACTIVE_ZOOM_EXTRA"] = "Pas supplémentaires (pendant la rotation)"
L["REACTIVE_ZOOM_EXTRA_DESC"] = "Ajouté en plus lorsque la caméra n'a pas encore rattrapé sa cible. C'est ce qui fait qu'une rotation rapide va bien plus loin que des crans lents."
L["REACTIVE_ZOOM_HEADER"] = "Zoom réactif"
L["REACTIVE_ZOOM_MAX_TIME"] = "Durée maximale du zoom"
L["REACTIVE_ZOOM_MAX_TIME_DESC"] = "Limite supérieure de la durée d'un zoom progressif. Plus bas paraît plus vif, plus haut paraît plus fluide."
L["REACTIVE_ZOOM_THRESHOLD"] = "Seuil de détection de rotation"
L["REACTIVE_ZOOM_THRESHOLD_DESC"] = "Écart minimal de la caméra avant que les pas supplémentaires ne s'activent. Plus bas réagit plus tôt."
L["REACTIVE_ZOOM_TOGGLE_DESC"] = "Remplace les pas de zoom fixes du client par un zoom progressif et accéléré."
L["WORLD_PVP_ZOOM"] = "Traiter le JcJ en monde ouvert comme une activité distincte"
L["WORLD_PVP_ZOOM_DESC"] = "Si activé, être marqué pour le JcJ ou avoir le mode Guerre actif à l'extérieur utilise la distance JcJ en monde ouvert plutôt que celle du monde ouvert. Désactivez si vous êtes marqué en permanence et souhaitez une distance unique."


-- Normal Distance baseline header
L["NORMAL_DISTANCE_HEADER"] = "Distance normale"
L["NORMAL_DISTANCE_HEADER_DESC"] = "La distance à laquelle la caméra revient lorsque vous n'êtes ni en combat ni en monture. Chaque activité ci-dessous est un écart par rapport à cette valeur de référence."


-- Adaptive combat return delay
L["ADAPTIVE_RETURN"] = "Délai de retour adaptatif"
L["ADAPTIVE_RETURN_DESC"] = "Tant que vous enchaînez les packs, la caméra mesure la durée des accalmies entre les monstres et attend assez longtemps pour les couvrir, au lieu de se rapprocher puis de s'éloigner à chaque pull. Dès que vous vous arrêtez, elle revient d'elle-même au délai que vous avez configuré."
L["ADAPTIVE_RETURN_MAX"] = "Plafond du délai adaptatif"
L["ADAPTIVE_RETURN_MAX_DESC"] = "La valeur maximale que le délai adaptatif peut atteindre. Le délai configuré pour l'activité reste le plancher."

if AceTable then
    for key, value in pairs(L) do
        AceTable[key] = value
    end
end

-- Brouillard volumétrique réservé à WoW: Forever
L["FOREVER_FOG_HEADER"] = "WoW: Forever — Brouillard volumétrique"
L["FOREVER_FOG_DESC"] = "Réglages graphiques réservés à Forever. Les valeurs par défaut sont lues directement depuis le client du jeu ; les changements écrivent immédiatement la CVar correspondante."
L["FOREVER_VOLUME_FOG"] = "Brouillard volumétrique"
L["FOREVER_VOLUME_FOG_DESC"] = "Contrôle volumeFog. 0 = désactivé, 1 = activé. Valeur par défaut du jeu : %s."
L["FOREVER_VOLUME_FOG_INTERIOR"] = "Brouillard volumétrique intérieur"
L["FOREVER_VOLUME_FOG_INTERIOR_DESC"] = "Contrôle volumeFogInterior. 0 = désactivé, 1 = activé. Valeur par défaut du jeu : %s."
L["FOREVER_VOLUME_FOG_LEVEL"] = "Qualité du brouillard volumétrique"
L["FOREVER_VOLUME_FOG_LEVEL_DESC"] = "Contrôle volumeFogLevel. Valeurs prises en charge : 0 à 3. Valeur par défaut du jeu : %d."
L["FOREVER_VOLUME_FOG_LEVEL_0"] = "0 — Minimum"
L["FOREVER_VOLUME_FOG_LEVEL_1"] = "1 — Niveau 1"
L["FOREVER_VOLUME_FOG_LEVEL_2"] = "2 — Niveau 2"
L["FOREVER_VOLUME_FOG_LEVEL_3"] = "3 — Maximum"

-- Contrôles d'environnement avancés réservés à WoW: Forever
L["FOREVER_ENVIRONMENT_HEADER"] = "WoW: Forever — Environnement avancé"
L["FOREVER_ENVIRONMENT_DESC"] = "Contrôle direct des CVar d'effets au sol au-delà des curseurs graphiques normaux. Le curseur Blizzard de densité du sol peut remplacer ces valeurs ; les changements externes sont synchronisés dans le profil au lieu d'être combattus par l'addon."
L["FOREVER_GROUND_EFFECT_OVERRIDE"] = "Gérer les effets au sol avancés"
L["FOREVER_GROUND_EFFECT_OVERRIDE_DESC"] = "Désactivé par défaut. À la première activation, l'addon récupère d'abord les valeurs brutes actuelles du client afin de ne pas modifier immédiatement le rendu, puis gère les trois réglages ci-dessous. La désactivation restaure les trois CVar aux valeurs par défaut de Forever."
L["FOREVER_RESET_DEFAULT"] = "Réinitialiser"
L["FOREVER_RESET_DEFAULT_DESC"] = "Restaure ce réglage à la valeur par défaut intégrée du client Forever."
L["FOREVER_GROUND_EFFECT_DENSITY"] = "Densité des effets au sol"
L["FOREVER_GROUND_EFFECT_DENSITY_DESC"] = "CVar groundEffectDensity direct. Plage : 16-256. Valeur par défaut du jeu : %d."
L["FOREVER_GROUND_EFFECT_DIST"] = "Distance des effets au sol"
L["FOREVER_GROUND_EFFECT_DIST_DESC"] = "CVar groundEffectDist direct. Plage : 32-600. Les valeurs supérieures au préréglage normal augmentent la distance d'affichage de la flore et des détails au sol. Valeur par défaut du jeu : %d."
L["FOREVER_GROUND_EFFECT_FADE"] = "Distance de fondu des effets au sol"
L["FOREVER_GROUND_EFFECT_FADE_DESC"] = "CVar groundEffectFade direct. Plage pratique exposée ici : 0-600. Une valeur proche de groundEffectDist réduit la disparition prématurée de la flore. Valeur par défaut du jeu : %d."

L["GAMEPAD_ACTIONCAM_DESC"] = "Action Camera is configured first in the Forever Gamepad panel; compatibility options follow it."
L["GAMEPAD_ACTIONCAM_INACTIVE"] = "|cffffcc00Action Camera est en pause tant que Enable Gamepad UI (Alpha) n’est pas activé dans le client Forever.|r"
L["GAMEPAD_ACTIONCAM_BLOCKED_CENTERED"] = "|cffff5555Action Camera est bloquée par CameraKeepCharacterCentered. MCD le désactive avant la caméra épaule/Dynamic Pitch puis restaure votre valeur d’origine.|r"
L["GAMEPAD_ACTIONCAM_BLOCKED_REDUCE"] = "|cffff5555La caméra épaule est bloquée par CameraReduceUnexpectedMovement. MCD le désactive avant d’appliquer le décalage puis restaure votre valeur d’origine.|r"
L["GAMEPAD_ACTIONCAM_BLOCKED_GENERIC"] = "|cffff5555La compatibilité Action Camera n’est pas prête (%s). Épaule/pitch restent à zéro jusqu’à la levée du blocage.|r"

L["GAMEPAD_ADVANCED_OVERRIDE_DESC"] = "API-only values start from the client's built-in defaults. Enabling management applies those defaults; disabling it restores them."

L["GAMEPAD_ACTIONCAM_COMPAT_HEADER"] = "Gamepad Compatibility"

L["GAMEPAD_ACTIONCAM_COMPAT_DESC"] = "Applied only while Action Camera requests the over-shoulder camera."

L["ACTION_CAM_SHOULDER_SWAP"] = "Changer d'épaule"
L["ACTION_CAM_SHOULDER_SWAP_DESC"] = "Inverse le décalage actuel de la caméra vers l'autre épaule."
L["ACTION_CAM_SHOULDER_CENTER"] = "Centrer"
L["ACTION_CAM_SHOULDER_CENTER_DESC"] = "Met le décalage d'épaule à zéro sans désactiver ActionCam."
L["BINDING_HEADER_MAXCAMDISTANCE"] = "Max Camera Distance"
L["BINDING_TOGGLE_SHOULDER"] = "Basculer la caméra d'épaule pour l'état actuel"
L["BINDING_SWAP_SHOULDER"] = "Changer de côté d'épaule"
L["BINDING_CENTER_SHOULDER"] = "Centrer la caméra d'épaule"
L["BINDING_OPEN_CAMERA_SETTINGS"] = "Ouvrir les réglages de caméra"
