local addonName = "Max_Camera_Distance"
local L = LibStub("AceLocale-3.0"):NewLocale(addonName, "zhCN")
if not L then return end

-- ============================================================================
-- 通用设置
-- ============================================================================
L["GENERAL_SETTINGS"] = "通用设置"
L["VERSION_PREFIX"] = "版本："

L["MAX_ZOOM_FACTOR"] = "最大镜头距离"
L["MAX_ZOOM_FACTOR_DESC"] = "设置游戏允许的绝对最大镜头距离（码）。"

L["MOVE_VIEW_DISTANCE"] = "缩放速度"
L["MOVE_VIEW_DISTANCE_DESC"] = "使用鼠标滚轮或快捷键时镜头缩放的速度。"

L["ZOOM_TRANSITION"] = "过渡平滑度"
L["ZOOM_TRANSITION_DESC"] = "镜头距离在战斗/坐骑/常规状态间平滑过渡的时间（秒）。数值越大，移动越慢、越平滑。"

L["YAW_MOVE_SPEED"] = "水平旋转速度"
L["YAW_MOVE_SPEED_DESC"] = "调整鼠标转向时镜头水平旋转（偏航）的速度。"

L["PITCH_MOVE_SPEED"] = "垂直旋转速度"
L["PITCH_MOVE_SPEED_DESC"] = "调整鼠标上下查看时镜头垂直旋转（俯仰）的速度。"

-- 界面 / 配置文件
L["WARNING_TEXT"] = "该插件突破了默认界面滑块的镜头距离限制，以提升团队副本、地下城和PvP中的视野。"

L["RELOAD_BUTTON"] = "重载界面"
L["RELOAD_BUTTON_DESC"] = "重载用户界面以应用关键更改。"

L["RESET_BUTTON"] = "恢复默认值"
L["RESET_BUTTON_DESC"] = "将此配置文件中的所有设置恢复为默认值。"

L["SETTINGS_CHANGED"] = "镜头设置已更新。"
L["SETTINGS_RESET"] = "配置文件已恢复为默认值。"
L["DB_NOT_READY"] = "数据库尚未初始化。"

-- 小地图
L["SHOW_MINIMAP_BUTTON"] = "显示小地图按钮"
L["SHOW_MINIMAP_BUTTON_DESC"] = "切换小地图图标显示状态。"

-- 通用状态
L["ENABLED"] = "|cff00ff00已启用|r"
L["DISABLED"] = "|cffff0000已禁用|r"

-- ============================================================================
-- 智能缩放（战斗 & 坐骑）
-- ============================================================================
L["COMBAT_SETTINGS"] = "智能缩放系统"
L["COMBAT_SETTINGS_WARNING"] = "|cffffd100系统逻辑：|r 根据你的状态自动调整镜头距离。\n\n|cffffd100优先级：|r |cffff5555战斗|r  >  |cff66ccff坐骑|r  >  |cffffffff常规|r"

-- 战斗
L["AUTO_ZOOM_COMBAT"] = "启用战斗智能缩放"
L["AUTO_ZOOM_COMBAT_DESC"] = "进入战斗时自动缩放到设定距离。（最高优先级）"

L["MAX_COMBAT_ZOOM_FACTOR"] = "战斗距离"
L["MAX_COMBAT_ZOOM_FACTOR_DESC"] = "处于战斗状态时的目标镜头距离。"

L["MIN_COMBAT_ZOOM_FACTOR"] = "常规距离"
L["MIN_COMBAT_ZOOM_FACTOR_DESC"] = "非战斗且未骑乘时的目标镜头距离。"

-- 区域设置
L["ZONES_HEADER"] = "战斗区域"
L["ZONES_DESC"] = "选择插件将|cff00ff00强制启用最大战斗缩放|r的区域。\n|cff888888禁用区域可让镜头控制更宽松。|r"

L["ZONE_PARTY"] = "地下城"
L["ZONE_RAID"] = "团队副本"
L["ZONE_ARENA"] = "竞技场"
L["ZONE_BG"] = "战场"
L["ZONE_SCENARIO"] = "场景战役 / 地渊孢林"

-- （代码片段中缺失但部分配置引用的项）
L["ZONE_WORLD"] = "野外战斗"
L["ZONE_WORLD_DESC"] = "野外任何战斗都会拉远镜头。警告：做任务时可能会感觉过于灵敏。"

L["ZONE_WORLD_BOSS"] = "世界首领 / 事件"
L["ZONE_WORLD_BOSS_DESC"] = "仅在野外首领战斗期间拉远镜头（检测到战斗中状态）。"

-- 坐骑 / 旅行
L["MOUNT_SETTINGS_HEADER"] = "坐骑与旅行设置"
L["AUTO_MOUNT_ZOOM"] = "启用坐骑自动缩放"
L["AUTO_MOUNT_ZOOM_DESC"] = "骑乘坐骑或进入旅行形态（德鲁伊/萨满/唤魔师）时自动拉远镜头。仅在非战斗状态下生效。"

L["MOUNT_ZOOM_FACTOR"] = "坐骑距离"
L["MOUNT_ZOOM_FACTOR_DESC"] = "骑乘坐骑/旅行时的目标镜头距离。"

-- 延迟设置
L["DISMOUNT_DELAY"] = "过渡延迟"
L["DISMOUNT_DELAY_DESC"] = "离开战斗或下马后，延迟多久（秒）将镜头拉回。"

-- Functions.lua 中使用的消息
L["SMART_ZOOM_MSG"] = "智能缩放：状态=%s，目标=%.1f码"
L["SMART_ZOOM_DISABLED_MSG"] = "智能缩放已禁用。使用手动最大距离设置。"

-- ============================================================================
-- 高级设置
-- ============================================================================
L["ADVANCED_SETTINGS"] = "高级设置"

L["REDUCE_UNEXPECTED_MOVEMENT"] = "减少意外移动"
L["REDUCE_UNEXPECTED_MOVEMENT_DESC"] = "减少镜头与地形/物体碰撞时的跳动（智能枢轴）。"

L["INDIRECT_VISIBILITY"] = "地形碰撞"
L["INDIRECT_VISIBILITY_DESC"] = "控制镜头与环境的交互方式（减少穿模）。"

L["RESAMPLE_ALWAYS_SHARPEN"] = "始终锐化（FSR）"
L["RESAMPLE_ALWAYS_SHARPEN_DESC"] = "强制游戏应用锐化滤镜（FidelityFX），即使未开启缩放也能让画面更清晰。"

L["SOFT_TARGET_INTERACT"] = "软目标交互图标"
L["SOFT_TARGET_INTERACT_DESC"] = "在游戏对象（邮箱、草药、传送门、NPC）上显示交互图标，便于选中目标。"

-- ============================================================================
-- 额外功能
-- ============================================================================
L["EXTRA_FEATURES"] = "额外功能"

-- 任务追踪
L["UNTRACK_QUESTS_BUTTON"] = "取消所有任务追踪"
L["UNTRACK_QUESTS_DESC"] = "立即移除任务追踪器中的所有任务，减少界面杂乱。"
L["QUEST_TRACKER_EMPTY"] = "任务追踪器已为空。"
L["QUEST_TRACKER_CLEARED"] = "已停止追踪 %d 个任务。"

-- 动作镜头
L["ACTION_CAM_HEADER"] = "动作镜头"
L["ACTION_CAM_DESC"] = "启用暴雪隐藏的动作镜头设置，带来现代RPG游戏的镜头体验。"

L["ACTION_CAM_SHOULDER_NAME"] = "肩后视角"
L["ACTION_CAM_SHOULDER_DESC"] = "将镜头轻微偏移到侧面（test_cameraOverShoulder）。包含智能偏移功能，近距离缩放时会恢复居中。"

L["ACTION_CAM_PITCH_NAME"] = "动态俯仰"
L["ACTION_CAM_PITCH_DESC"] = "根据移动状态调整镜头角度（test_cameraDynamicPitch）。"

L["CONFLICT_FIX_MSG"] = "动作镜头：已禁用「保持角色居中」以防止镜头抖动。"

-- 暂离模式
L["AFK_MODE_HEADER"] = "暂离模式"
L["AFK_MODE_DESC_SAFE"] = "|cff00ff00安全模式：|r 若界面已隐藏，按下|cffffd100ESC|r将立即恢复界面并退出暂离模式。"
L["AFK_MODE_ENABLE"] = "启用暂离旋转"
L["AFK_MODE_ENABLE_DESC"] = "暂离时自动拉远镜头并旋转视角。隐藏界面以获得电影级效果。"

-- 暂离逻辑使用的消息
L["AFK_ENTER_MSG"] = "暂离模式：已启用（电影级旋转）。"
L["AFK_EXIT_MSG"] = "暂离模式：已禁用（恢复界面和镜头）。"

-- ============================================================================
-- 命令 / 帮助
-- ============================================================================
L["CMD_USAGE"] = "用法：/mcd config | autozoom | automount"

-- 可选（若其他文件中使用）
L["ZOOM_SET_MESSAGE"] = "缩放已设置为 %s（%.1f码）"

-- ============================================================================
-- 钩子 / 系统消息
-- ============================================================================
L["HOOK_DISABLED_BY_ADDON"] = "|cffff0000已被MaxCameraDistance禁用|r"
L["HOOK_MOUSE_SPEED_DESC"] = "鼠标视角速度由插件设置单独控制（水平/垂直）："
L["HOOK_MOUSE_SPEED_PATH"] = "/mcd config -> 通用设置"

-- ============================================================================
-- 调试
-- ============================================================================
L["DEBUG_SETTINGS"] = "调试设置"
L["ENABLE_DEBUG_LOGGING"] = "启用日志记录"
L["ENABLE_DEBUG_LOGGING_DESC"] = "在聊天框打印状态变化（战斗/坐骑/暂离）和CVar更新的调试信息。"

L["DEBUG_LEVEL"] = "调试等级"
L["DEBUG_LEVEL_DESC"] = "选择日志的详细程度。"
L["DEBUG_LEVEL_ERROR"] = "错误"
L["DEBUG_LEVEL_WARNING"] = "警告"
L["DEBUG_LEVEL_INFO"] = "信息"
L["DEBUG_LEVEL_DEBUG"] = "详细"

L["COMBAT_HEADER"] = "战斗"
L["ZONE_CATEGORY_PVP"] = "PvP"
L["ZONE_CATEGORY_PVE"] = "PvE"
L["ZONE_ZOOM_FACTOR"] = "区域距离"
L["ZONE_ZOOM_FACTOR_DESC"] = "在已启用的团队、副本、竞技场、战场或场景区域中使用的目标镜头距离。这样你可以在其他地方保留更小的战斗距离。"
L["DELAY_HEADER"] = "过渡延迟"
L["ACTION_CAM_SHOULDER_IN_COMBAT_NAME"] = "战斗时肩部视角"
L["ACTION_CAM_SHOULDER_IN_COMBAT_DESC"] = "在战斗中启用肩部偏移镜头。"
L["ACTION_CAM_SHOULDER_OUT_OF_COMBAT_NAME"] = "脱战时肩部视角"
L["ACTION_CAM_SHOULDER_OUT_OF_COMBAT_DESC"] = "在脱离战斗时启用肩部偏移镜头。"

L["WORLD_COMBAT_ZOOM_FACTOR"] = "开放世界战斗距离"
L["WORLD_COMBAT_ZOOM_FACTOR_DESC"] = "在开放世界进入战斗时的目标镜头距离。"
L["PARTY_COMBAT_ZOOM_FACTOR"] = "小队战斗距离"
L["PARTY_COMBAT_ZOOM_FACTOR_DESC"] = "当你在小队、副本、地下堡或类似小规模内容中战斗时使用的目标镜头距离。"
L["RAID_COMBAT_ZOOM_FACTOR"] = "团队战斗距离"
L["RAID_COMBAT_ZOOM_FACTOR_DESC"] = "当你在团队副本或其他大型团队内容中战斗时使用的目标镜头距离。"
L["GROUP_COMBAT_ZOOM_FACTOR"] = "队伍 / 团队战斗距离"
L["GROUP_COMBAT_ZOOM_FACTOR_DESC"] = "在队伍、副本、团队或类似组队内容中进入战斗时的目标镜头距离。"
L["PVP_COMBAT_ZOOM_FACTOR"] = "PvP 战斗距离"
L["PVP_COMBAT_ZOOM_FACTOR_DESC"] = "在 PvP 内容中进入战斗时的目标镜头距离。"

L["PROFILES"] = "配置文件"
L["PROFILES_MISSING_LIB_DESC"] = "未找到 AceDBOptions-3.0，因此无法使用高级配置文件控制。"


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
L["PRESET_SECTION_DESC"] = "Presets convert high-level choices into real distances. If a preset other than Manual is selected, the matching slider is locked automatically."
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
L["MANUAL_SECTION_DESC"] = "Manual controls stay available only when the matching preset is set to Manual."
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
L["DEBUG_LOGGING_DESC"] = "These options control what gets printed to chat. Live Status above is always available even with logging disabled."
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


L["DELAY_HEADER_DESC"] = "Combat zoom-out is instant. Returning to Normal is delayed per context to avoid camera flicker."
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

L["STATUS_CONTEXT_INACTIVE"] = "Inactive"
L["STATUS_REASON_FORCED"] = "Forced Encounter"
