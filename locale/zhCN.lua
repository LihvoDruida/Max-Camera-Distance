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