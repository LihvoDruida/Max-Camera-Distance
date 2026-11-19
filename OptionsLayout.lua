-- Reuse option handlers and profile keys while arranging controls by task.
local _, ns = ...
local Layout = {}
ns.OptionsLayout = Layout

function Layout:Apply(options)
    local root = options.args
    local L = ns.Locale
    local function page(key, label, order, hidden)
        root[key] = { type = "group", name = L:Get(label), order = order, hidden = hidden, args = {} }
        return root[key].args
    end
    local function move(source, target, keys, first)
        for i, key in ipairs(keys) do
            if source[key] then
                target[key] = source[key]; source[key] = nil
                if first then target[key].order = first + i - 1 end
            end
        end
    end
    local general, presets, combat, extra = root.generalSettings.args, root.presetSettings.args,
        root.smartSettings.args, root.extraFeatures.args
    root.generalSettings.order = 2
    local zoom = page("zoomSettings", "REACTIVE_ZOOM_HEADER", 3)
    move(general, zoom, { "zoomTransition", "moveViewDistance", "reactiveZoomHeader", "reactiveZoomDesc",
        "reactiveZoom", "reactiveZoomAddIncrementsAlways", "reactiveZoomAddIncrements",
        "reactiveZoomIncAddDifference", "reactiveZoomMaxZoomTime", "reactiveZoomEasing", "reactiveZoomSpeed" }, 1)
    move(presets, general, { "manualMaxPreset", "manualMaxPresetInfo" }, 8)

    -- Preset, manual distance and return delay live together for each activity.
    move(presets, combat, { "normalZoomPreset", "normalZoomPresetInfo" }, 43.1)
    combat.manualCombatHeader, combat.manualCombatDesc = nil, nil
    combat.delayHeader, combat.delayDesc = nil, nil
    for _, key in ipairs({ "slider", "delay" }) do
        for _, kind in ipairs({ "neutral", "pvp", "pve" }) do combat["ctxHeader_" .. key .. "_" .. kind] = nil end
    end
    local kindOrder = { neutral = 46, pvp = 47, pve = 48 }
    for _, id in ipairs(ns.Contexts.ORDER) do
        local def = ns.Contexts.DEFINITIONS[id]
        local slider = combat["ctxSlider_" .. id]
        if slider then
            local kindKey = "activities_" .. def.kind
            if not combat[kindKey] then
                combat[kindKey] = { type = "group", inline = true, order = kindOrder[def.kind],
                    name = L:Get("CONTEXT_GROUP_" .. def.kind:upper()), args = {} }
            end
            local activity = { type = "group", inline = true, order = def.order,
                name = L:Get(id == "scenario" and not ns.Compat.IS_RETAIL and "CONTEXT_SCENARIO_CLASSIC" or def.labelKey), args = {} }
            combat[kindKey].args[id] = activity
            move(presets, activity.args, { "ctxPreset_" .. id, "ctxPresetInfo_" .. id }, 1)
            move(combat, activity.args, { "ctxSlider_" .. id, "ctxDelay_" .. id }, 3)
            activity.args["ctxPreset_" .. id].name = L:Get("UI_ACTIVITY_PRESET")
            slider.name = L:Get("UI_DISTANCE")
            activity.args["ctxDelay_" .. id].name = L:Get("UI_RETURN_DELAY")
        end
    end
    root.presetSettings = nil

    -- "When to return" closes the combat page: triggers -> distances -> return.
    combat.returnHeader = { type = "header", name = L:Get("DELAY_HEADER"), order = 49 }
    if combat.adaptiveCombatReturn then combat.adaptiveCombatReturn.order = 49.1 end
    if combat.adaptiveCombatReturnMax then combat.adaptiveCombatReturnMax.order = 49.2 end

    local mounts = page("mountSettings", "MOUNT_SETTINGS_HEADER", 5)
    move(combat, mounts, { "mountHeader", "autoMountZoom", "mountZoomMode", "dragonRacingRaceFirstPerson" }, 1)
    move(presets, mounts, { "mountZoomPreset", "mountZoomPresetInfo" }, 5)
    move(combat, mounts, { "mountZoomFactor", "dismountDelay" }, 7)
    combat.zoomRestoreSetting.order, combat.respectManualStateZoom.order = 15, 16
    combat.zoomRestoreSetting.sorting = { "never", "adaptive", "always" }
    mounts.mountZoomMode.sorting = { "all", "flying", "skyriding", "forms" }

    local action = page("actionCamSettings", "ACTION_CAM_HEADER", 6,
        function() return ns.Compat.IS_FOREVER or not ns.Compat.SupportsActionCam() end)
    move(extra, action, { "actionCamHeader", "descActionCam", "enableShoulderInCombat", "enableShoulderOutOfCombat",
        "enableDynamicPitch", "shoulderOffset", "shoulderOffsetReset", "shoulderOffsetSwap", "shoulderOffsetCenter",
        "shoulderModelCompensation", "shoulderSmartFade", "shoulderFadeEnd", "shoulderFadeStart" }, 1)
    root.gamePadSettings.order = 6.5
    local afk = page("afkSettings", "AFK_MODE_HEADER", 7)
    move(extra, afk, { "afkHeader", "descAFK", "enableAFK", "afkHideUI", "afkZoomOut", "afkZoomDistance", "afkDelay",
        "afkDirection", "afkRotationSpeed", "afkSkipMounted", "afkSkipFlying", "afkResumeAfterCombat" }, 1)
    local graphics = page("foreverGraphics", "UI_FOREVER_GRAPHICS", 9, function()
        if not ns.Compat.IS_FOREVER then return true end
        for _, cvar in ipairs({ "volumeFog", "volumeFogInterior", "volumeFogLevel",
            "groundEffectDensity", "groundEffectDist", "groundEffectFade" }) do
            if ns.Compat.HasCVar(cvar) then return false end
        end
        return true
    end)
    move(extra, graphics, { "foreverFogHeader", "foreverFogDesc", "volumeFog", "volumeFogInterior", "volumeFogLevel",
        "foreverEnvironmentHeader", "foreverEnvironmentDesc", "foreverGroundEffectsOverride", "groundEffectDensity",
        "groundEffectDensityReset", "groundEffectDist", "groundEffectDistReset", "groundEffectFade", "groundEffectFadeReset" }, 1)
    root.advancedSettings.order = 8

    -- Task-oriented pages (roadmap stage 4). Every option keeps its handler and
    -- profile key; only where it is shown changes.
    -- 1) Combat: what enables the camera and when it returns. Per-activity
    --    distances get their own page instead of 25 rows on the same scroll.
    root.smartSettings.name = L:Get("COMBAT_SETTINGS")
    move(zoom, combat, { "zoomTransition" }, 13)
    local activities = page("activitySettings", "UI_ACTIVITY_DISTANCES", 4.5)
    move(combat, activities, { "normalDistanceHeader", "normalDistanceDesc", "normalZoomPreset",
        "combatMinZoom", "normalZoomPresetInfo" }, 1)
    move(combat, activities, { "activities_neutral" }, 11)
    move(combat, activities, { "activities_pve" }, 12)
    -- PvP activities are a separate page: on Retail eight activities with three
    -- controls each would otherwise fill one scroll with 26 controls.
    local pvp = page("pvpActivitySettings", "UI_PVP_DISTANCES", 4.6, function()
        return not combat.activities_pvp and not (root.pvpActivitySettings and next(root.pvpActivitySettings.args))
    end)
    move(combat, pvp, { "activities_pvp" }, 1)

    -- 2) Mouse wheel and zoom speed on one page with a name that says so.
    root.zoomSettings.name = L:Get("UI_WHEEL_PAGE")

    -- 3) The one-button "Extra Features" page joins the world/visual page.
    local advanced = root.advancedSettings.args
    root.advancedSettings.name = L:Get("UI_WORLD_PAGE")
    if extra.clearTrackerBtn then
        advanced.worldHeader = { type = "header", name = L:Get("UI_QUESTS_HEADER"), order = 30,
            hidden = extra.clearTrackerBtn.hidden }
        move(extra, advanced, { "clearTrackerBtn" }, 31)
    end
    root.extraFeatures = nil

    -- 4) A full reset belongs with the profiles, not next to Reload UI.
    move(root.reloadGroup.args, root.profiles.args, { "resetBtn" }, 7)

    root.debugSettings.order, root.profiles.order = 11, 12

    -- Every settings page ends with a reset of just that page.
    for key, group in pairs(root) do
        if type(group) == "table" and group.type == "group" and group.args
            and key ~= "reloadGroup" and key ~= "debugSettings" and key ~= "profiles" then
            local pageKey = key
            group.args.pageReset = {
                type = "execute", confirm = true, order = 999,
                name = L:Get("UI_RESET_PAGE"),
                desc = L:Get("UI_RESET_PAGE_DESC"),
                func = function() ns.Config:ResetPage(pageKey) end,
            }
        end
    end
    root.reloadGroup.args.languageOverride.sorting = ns.Locale.order
end
