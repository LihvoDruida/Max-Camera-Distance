local addonName, ns = ...
ns.LocaleData = ns.LocaleData or {}
local L = {}
ns.LocaleData["zhCN"] = L

local AceLocale = LibStub("AceLocale-3.0", true)
local AceTable = AceLocale and AceLocale:NewLocale(addonName, "zhCN")

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
L["ZOOM_TRANSITION_DESC"] = "镜头距离在 |cffff5555战斗|r、|cff66ccff坐骑|r 和 |cffffffff常规状态|r 之间平滑过渡的时间（秒）。数值越大，移动越慢、越平滑。"
L["YAW_MOVE_SPEED"] = "水平旋转速度"
L["YAW_MOVE_SPEED_DESC"] = "调整鼠标转向时镜头水平旋转（偏航）的速度。"

L["PITCH_MOVE_SPEED"] = "垂直旋转速度"
L["PITCH_MOVE_SPEED_DESC"] = "调整鼠标上下查看时镜头垂直旋转（俯仰）的速度。"

-- 界面 / 配置文件
L["WARNING_TEXT"] = "|cffffd100注意：|r该插件突破了默认 Blizzard 滑块的镜头距离限制，以提升团队副本、地下城和 PvP 中的视野。"
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
L["COMBAT_SETTINGS_WARNING"] = "|cffffd100系统逻辑：|r 根据你的状态自动调整镜头距离。

|cffffd100优先级：|r |cffff5555战斗|r  >  |cff66ccff坐骑|r  >  |cffffffff常规|r"
-- 战斗
L["AUTO_ZOOM_COMBAT"] = "启用战斗智能缩放"
L["AUTO_ZOOM_COMBAT_DESC"] = "进入战斗时自动缩放到设定距离。|cffff5555最高优先级。|r"
L["MAX_COMBAT_ZOOM_FACTOR"] = "战斗距离"
L["MAX_COMBAT_ZOOM_FACTOR_DESC"] = "处于 |cffff5555战斗状态|r 时的目标镜头距离。"
L["MIN_COMBAT_ZOOM_FACTOR"] = "常规距离"
L["MIN_COMBAT_ZOOM_FACTOR_DESC"] = "处于 |cffffffff非战斗|r 且 |cff66ccff未骑乘|r 状态时的目标镜头距离。"
-- 区域设置
L["ZONES_HEADER"] = "战斗区域"
L["ZONES_DESC"] = "选择插件将 |cff00ff00强制启用最大战斗缩放|r 的区域。
|cff888888禁用某些区域可让镜头控制更宽松。|r"
L["ZONE_PARTY"] = "地下城"
L["ZONE_RAID"] = "团队副本"
L["ZONE_ARENA"] = "竞技场"
L["ZONE_BG"] = "战场"
L["ZONE_SCENARIO"] = "场景战役 / 地渊孢林"

-- （代码片段中缺失但部分配置引用的项）
L["ZONE_WORLD"] = "野外战斗"
L["ZONE_WORLD_DESC"] = "在开放世界中，|cffff5555任何战斗|r 都会拉远镜头。|cffffd100警告：|r做任务时可能会感觉过于激进。"
L["ZONE_WORLD_BOSS"] = "世界首领 / 事件"
L["ZONE_WORLD_BOSS_DESC"] = "仅在野外首领战斗期间拉远镜头（检测到战斗中状态）。"

-- 坐骑 / 旅行
L["MOUNT_SETTINGS_HEADER"] = "坐骑与旅行设置"
L["AUTO_MOUNT_ZOOM"] = "启用坐骑自动缩放"
L["AUTO_MOUNT_ZOOM_DESC"] = "骑乘坐骑或进入旅行形态（德鲁伊/萨满/唤魔师）时自动拉远镜头。仅在 |cffffffff非战斗|r 状态下生效。"
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
L["AFK_MODE_DESC_SAFE"] = "|cff00ff00安全模式：|r 若界面已隐藏，按下 |cffffd100ESC|r 将立即恢复界面并退出暂离模式。"
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
L["HOOK_DISABLED_BY_ADDON"] = "|cffff0000已被 MaxCameraDistance 禁用|r"
L["HOOK_MOUSE_SPEED_DESC"] = "鼠标视角速度由插件设置单独控制（水平/垂直）："
L["HOOK_MOUSE_SPEED_PATH"] = "/mcd config -> 通用设置"

-- ============================================================================
-- 调试
-- ============================================================================
L["DEBUG_SETTINGS"] = "调试设置"
L["ENABLE_DEBUG_LOGGING"] = "启用日志记录"
L["ENABLE_DEBUG_LOGGING_DESC"] = "在聊天框打印关于状态变化 |cffff5555（战斗/坐骑/暂离）|r 和 CVar 更新的调试信息。"
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


L["ZONE_CONTEXT_HEADER"] = "上下文规则"
L["ZONE_CONTEXT_DESC"] = "这些开关决定了小队、团队、战场、竞技场和场景/地下堡中的战斗，是使用各自的专用预设，还是回退到开放世界战斗距离。"
L["ZONE_PARTY_DESC"] = "在地下城和小队内容中使用小队战斗距离。禁用后将回退为开放世界战斗距离。"
L["ZONE_RAID_DESC"] = "在团队副本内容中使用团队战斗距离。禁用后将回退为开放世界战斗距离。"
L["ZONE_ARENA_DESC"] = "在竞技场中使用 PvP 战斗距离。禁用后将回退为开放世界战斗距离。"
L["ZONE_BG_DESC"] = "在战场中使用 PvP 战斗距离。禁用后将回退为开放世界战斗距离。"
L["ZONE_SCENARIO_DESC"] = "在场景和地下堡中使用小队战斗距离。禁用后将回退为开放世界战斗距离。"

L["STATUS_HEADER"] = "实时状态"
L["STATUS_DESC"] = "显示当前实际生效的缩放结果，以及为什么会选择该结果。"
L["STATUS_UNAVAILABLE"] = "实时状态当前不可用。"
L["STATUS_ZOOM_STATE"] = "缩放状态"
L["STATUS_CONTEXT"] = "最终上下文"
L["STATUS_RAW_CONTEXT"] = "原始上下文"
L["STATUS_ZONE_SOURCE"] = "区域来源"
L["STATUS_TARGET_DISTANCE"] = "目标距离"
L["STATUS_WORLD_FALLBACK"] = "使用世界回退"
L["STATUS_REASON_FLAGS"] = "原因标记"
L["STATUS_ZONE_FLAGS"] = "区域标记"
L["STATUS_YES"] = "是"
L["STATUS_NO"] = "否"
L["STATUS_STATE_NONE"] = "无"
L["STATUS_STATE_MOUNT"] = "坐骑"
L["STATUS_STATE_COMBAT"] = "战斗"
L["STATUS_CONTEXT_WORLD"] = "世界"
L["STATUS_CONTEXT_PARTY"] = "小队"
L["STATUS_CONTEXT_RAID"] = "团队"
L["STATUS_CONTEXT_PVP"] = "PvP"
L["STATUS_ZONE_SOURCE_WORLD"] = "世界"
L["STATUS_ZONE_SOURCE_PARTY"] = "小队"
L["STATUS_ZONE_SOURCE_RAID"] = "团队"
L["STATUS_ZONE_SOURCE_ARENA"] = "竞技场"
L["STATUS_ZONE_SOURCE_BG"] = "战场"
L["STATUS_ZONE_SOURCE_SCENARIO"] = "场景 / 地下堡"

L["STATUS_REASON_PLAYER"] = "玩家"
L["STATUS_REASON_GROUP"] = "队伍"
L["STATUS_REASON_THREAT"] = "仇恨"
L["STATUS_REASON_MOUNTED"] = "已骑乘"
L["STATUS_REASON_WORLD_BOSS"] = "世界首领"


L["PRESET_SETTINGS"] = "预设"
L["PRESET_SECTION_HEADER"] = "距离预设"
L["PRESET_SECTION_DESC"] = "预设会把高级选择转换为实际距离。如果选择的不是 |cffffd100手动|r，对应的滑块会被自动 |cffff5555锁定|r。"
L["PRESET_MANUAL_GROUP_HEADER"] = "手动 / 常规"
L["PRESET_COMBAT_GROUP_HEADER"] = "战斗预设"
L["PRESET_MOUNT_GROUP_HEADER"] = "坐骑 / 旅行"
L["PRESET_MANUAL"] = "手动"
L["PRESET_CLIENT_DEFAULT"] = "游戏默认"
L["PRESET_CLOSE"] = "近"
L["PRESET_BALANCED"] = "平衡"
L["PRESET_FAR"] = "远"
L["PRESET_MAX"] = "最大"
L["PRESET_STATUS_UNAVAILABLE"] = "预设状态当前不可用。"
L["PRESET_STATUS_MANUAL"] = "当前启用手动控制。滑块值：%.1f 码。"
L["PRESET_STATUS_LOCKED"] = "当前预设：%s。实际距离：%.1f 码。对应的手动控制会锁定，直到你切换回“手动”。"
L["PRESET_UNKNOWN"] = "未知"
L["MANUAL_SECTION_HEADER"] = "手动镜头控制"
L["MANUAL_SECTION_DESC"] = "只有当对应预设设置为 |cffffd100手动|r 时，手动控制才会可用。"
L["MANUAL_COMBAT_HEADER"] = "手动距离"
L["MANUAL_COMBAT_DESC"] = "这些滑块仅在对应预设设置为“手动”时才会生效。"
L["MANUAL_MAX_PRESET"] = "最大距离手动预设"
L["NORMAL_ZOOM_PRESET"] = "常规距离预设"
L["WORLD_COMBAT_PRESET"] = "开放世界战斗预设"
L["PARTY_COMBAT_PRESET"] = "小队战斗预设"
L["RAID_COMBAT_PRESET"] = "团队战斗预设"
L["PVP_COMBAT_PRESET"] = "PvP 战斗预设"
L["MOUNT_ZOOM_PRESET"] = "坐骑距离预设"

L["STATUS_DISTANCE_SOURCE"] = "距离来源"


L["DEBUG_SETTINGS"] = "状态与调试"
L["DEBUG_LOGGING_HEADER"] = "聊天日志"
L["DEBUG_LOGGING_DESC"] = "这些选项控制哪些信息会输出到聊天框。上方的 |cffffd100实时状态|r 模块即使关闭日志也始终可用。"
L["COMBAT_TRIGGER_HEADER"] = "战斗触发条件"
L["COMBAT_TRIGGER_DESC"] = "选择哪些事件可以触发战斗缩放。"
L["COMBAT_TRIGGER_PLAYER"] = "我进入战斗时缩放"
L["COMBAT_TRIGGER_PLAYER_DESC"] = "当你的角色进入战斗时触发战斗缩放。"
L["COMBAT_TRIGGER_GROUP"] = "小队或团队进入战斗时缩放"
L["COMBAT_TRIGGER_GROUP_DESC"] = "当你的小队或团队进入战斗时触发战斗缩放，即使你自己还没有正式进入战斗。"
L["COMBAT_TRIGGER_THREAT"] = "仅在有仇恨时缩放"
L["COMBAT_TRIGGER_THREAT_DESC"] = "当你获得仇恨时触发战斗缩放，即使常规战斗标记还未完全稳定。"
L["STATUS_TRIGGER_RULES"] = "触发规则"
L["STATUS_ACTIVE_TRIGGERS"] = "当前激活的触发条件"


L["DELAY_HEADER_DESC"] = "战斗时拉远会立即生效。返回 |cffffffff常规状态|r 会根据不同上下文延迟执行，以避免镜头闪烁。"
L["WORLD_COMBAT_RETURN_DELAY"] = "开放世界返回延迟"
L["WORLD_COMBAT_RETURN_DELAY_DESC"] = "开放世界战斗结束后，延迟多久再返回常规距离。"
L["PARTY_COMBAT_RETURN_DELAY"] = "小队返回延迟"
L["PARTY_COMBAT_RETURN_DELAY_DESC"] = "小队或地下城战斗结束后，延迟多久再返回常规距离。"
L["RAID_COMBAT_RETURN_DELAY"] = "团队返回延迟"
L["RAID_COMBAT_RETURN_DELAY_DESC"] = "团队战斗结束后，延迟多久再返回常规距离。"
L["STATUS_RETURN_DELAYS"] = "返回延迟"
L["STATUS_PENDING_RETURN"] = "待执行返回"
L["STATUS_PENDING_RETURN_NONE"] = "当前没有待执行的延迟返回。"
L["STATUS_PENDING_RETURN_ACTIVE"] = "%s：%s，剩余 %.1f 秒（总计 %.1f 秒）。"
L["STATUS_RETURN_KIND_COMBAT"] = "战斗返回"
L["STATUS_RETURN_KIND_MOUNT"] = "坐骑返回"

L["OCCLUDED_SILHOUETTE_PLAYER"] = "被遮挡时显示轮廓"
L["OCCLUDED_SILHOUETTE_PLAYER_DESC"] = "当角色被物体遮挡时启用暴雪的角色轮廓显示。这是全局客户端设置，会在所有场景生效。"
L["STATUS_SILHOUETTE"] = "被遮挡时显示轮廓"
L["HOOK_SILHOUETTE_DESC"] = "角色轮廓显示由插件设置控制："
L["HOOK_SILHOUETTE_PATH"] = "/mcd config -> 高级设置 -> 视觉辅助"
L["HOOK_SILHOUETTE_LABEL_OBSTRUCTED"] = "被遮挡时显示轮廓"
L["HOOK_SILHOUETTE_LABEL_OBSCURED"] = "被遮蔽时显示轮廓"


-- 摄像机碰撞
L["INDIRECT_OFFSET"] = "碰撞灵敏度"
L["INDIRECT_OFFSET_DESC"] = "控制 Blizzard 的降低镜头碰撞灵敏度。|cff66ccff0.0|r 为最小值，|cffff555510.0|r 为最大值，游戏默认值为 |cffffd1001.5|r。数值越高，在镜头被拉近前可容忍的遮挡越多。"
L["COLLISION_HEADER"] = "镜头碰撞"
L["COLLISION_DESC"] = "镜头碰撞的通用行为。这些设置是 |cffffd100全局|r 的，会在所有场景下生效，而不是按战斗情境区分。"
L["COLLISION_SUMMARY_TEXT"] = "|cff66ccff降低镜头碰撞：|r %s
|cff66ccff碰撞灵敏度：|r %s
|cff66ccff被遮挡时显示轮廓：|r %s
|cff66ccff减少意外移动：|r %s
|cff888888这些设置是全局的，在所有场景下生效。|r"
L["VISUAL_UTILITY_HEADER"] = "视觉辅助"

-- 坐骑 / 旅行形态模式
L["MOUNT_ZOOM_MODE_NAME"] = "坐骑缩放模式"
L["MOUNT_ZOOM_MODE_DESC"] = "选择自动坐骑缩放应用于所有坐骑和旅行形态、仅飞行坐骑、仅 Skyriding，或仅旅行形态。"
L["MOUNT_ZOOM_MODE_ALL"] = "所有坐骑和旅行形态"
L["MOUNT_ZOOM_MODE_FLYING"] = "仅飞行坐骑"
L["MOUNT_ZOOM_MODE_SKYRIDING"] = "仅 Skyriding"
L["MOUNT_ZOOM_MODE_FORMS"] = "仅旅行形态"

L["DRAGON_RACE_FP_NAME"] = "Skyriding 竞速时启用第一人称"
L["DRAGON_RACE_FP_DESC"] = "当 Skyriding 竞速光环激活时，临时切换为第一人称视角，并在竞速结束后恢复智能缩放控制。"

-- 状态
L["STATUS_COLLISION_ENABLED"] = "降低镜头碰撞"
L["STATUS_COLLISION_OFFSET"] = "碰撞灵敏度"
L["STATUS_SMART_PIVOT"] = "减少意外移动"
L["STATUS_MOUNT_MODE"] = "坐骑缩放模式"
L["STATUS_TRAVEL_SIGNALS"] = "旅行状态"
L["STATUS_MOUNT_ZOOM_ACTIVE"] = "坐骑缩放已激活"
L["STATUS_FLYING_MOUNT"] = "飞行坐骑"
L["STATUS_SKYRIDING"] = "Skyriding"
L["STATUS_DRAGON_RACE"] = "Skyriding 竞速"
L["STATUS_DRAGON_RACE_FP"] = "竞速第一人称"


L["AFK_HIDE_UI_NAME"] = "AFK 时隐藏界面"
L["AFK_HIDE_UI_DESC"] = "为获得更具电影感的 AFK 模式，隐藏整个界面。|cffffd100ESC|r 可安全恢复，无需等待 AFK 标记重置。"
L["AFK_ZOOM_OUT_NAME"] = "AFK 时拉远镜头"
L["AFK_ZOOM_OUT_DESC"] = "进入 AFK 模式时，将镜头推到插件管理的最大距离。"
L["AFK_DELAY_NAME"] = "启动延迟"
L["AFK_DELAY_DESC"] = "在角色进入 AFK 状态后，等待多少秒再启动电影模式。"
L["AFK_DIRECTION_NAME"] = "旋转方向"
L["AFK_DIRECTION_DESC"] = "选择 AFK 模式下镜头旋转的方向。"
L["AFK_DIRECTION_LEFT"] = "向左"
L["AFK_DIRECTION_RIGHT"] = "向右"
L["AFK_SPEED_NAME"] = "旋转速度"
L["AFK_SPEED_DESC"] = "用于 AFK 旋转的标准化 MoveView 速度。值越小，移动越平稳。"
L["AFK_SKIP_MOUNTED_NAME"] = "骑乘时不启动"
L["AFK_SKIP_MOUNTED_DESC"] = "当角色处于坐骑状态时，阻止 AFK 模式启动。"
L["AFK_SKIP_FLYING_NAME"] = "飞行时不启动"
L["AFK_SKIP_FLYING_DESC"] = "当角色处于飞行状态时，阻止 AFK 模式启动。"
L["AFK_RESUME_AFTER_COMBAT_NAME"] = "战斗后恢复"
L["AFK_RESUME_AFTER_COMBAT_DESC"] = "如果战斗中断了 AFK 模式，那么在战斗结束后且你仍处于 AFK 状态时，会重新启用它。"
L["ZOOM_RESTORE_SETTING"] = "缩放恢复行为"
L["ZOOM_RESTORE_SETTING_DESC"] = "控制 Smart Zoom 如何恢复先前使用过的缩放值。|cffffd100永不|r = 始终使用已配置的目标。|cffffd100自适应|r = 仅在返回到刚刚离开的状态时恢复上一次缩放。|cffffd100始终|r = 只要未超出该状态上限，就优先使用该状态最后保存的缩放值。"
L["ZOOM_RESTORE_NEVER"] = "永不"
L["ZOOM_RESTORE_ADAPTIVE"] = "自适应"
L["ZOOM_RESTORE_ALWAYS"] = "始终"
L["RESPECT_MANUAL_STATE_ZOOM"] = "在智能状态中保留手动缩放"
L["RESPECT_MANUAL_STATE_ZOOM_DESC"] = "当 Smart Zoom 在坐骑或战斗状态下生效时，鼠标滚轮手动缩放会一直保留到状态发生变化，而不是在每次刷新时被强制改回去。"
L["STATUS_DYNAMIC_BEHAVIOR"] = "动态行为"

L["LANGUAGE_SETTING"] = '插件语言'
L["LANGUAGE_SETTING_DESC"] = "选择插件语言。|cffffd100客户端默认|r 会跟随游戏客户端语言。修改此选项后界面会 |cffff5555立即重载|r。"
L["LANGUAGE_CLIENT_DEFAULT"] = '客户端默认'
L["ADDON_TITLE"] = 'Max Camera Distance'
L["MINIMAP_TOOLTIP_OPEN_SETTINGS"] = '点击打开设置'
L["SETTINGS_APPLIED_FULL"] = "|cff00ff00已应用|r — 距离：%.1f |cff888888（过渡 %.2fs）|r"

if AceTable then
    for key, value in pairs(L) do
        AceTable[key] = value
    end
end
