local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = QBCore.Functions.GetPlayerData()

-- State Variables
local HotdogBlip, StandObject, SpatelObject, HotdogObject = nil, nil, nil, nil
local IsWorking, IsPushing, IsUIActive, PreparingFood, zoneMade = false, false, false, false, false
local TextState, IsTextVisible, CurrentTextPrompt, CurrentTextCoords = nil, false, nil, nil
local LastSellingState = nil -- Track selling state to prevent flashing
local LastNoDogsNotify = 0 -- Cooldown for "no dogs" notification (prevent spam)
local CurrentSellPrompt = nil -- Dynamic sell hint shown in NUI controls panel
local ActiveLoopsStarted = false -- Ensure worker loops only start once per work session
local HTMLMinigamePending = false
local HTMLMinigameResult = nil

-- PolyZone Variables
local StandZones = {
    GrabZone = nil,
    PrepareZone = nil,
    SellingZone = nil,
}
local InStandZones = {
    Grab = false,
    Prepare = false,
    Selling = false,
}

local SellingData = {
    Enabled = false,
    Target = nil,
    HasTarget = false,
    RecentPeds = {}, -- hash set for O(1) membership
    Hotdog = nil,
    Personality = nil,
    DemandMultiplier = 1.0,
    DemandLabel = 'default',
}

-- Constants
local OffsetData = { x = 0.0, y = -0.8, z = 1.0, Distance = 2 }
local AnimationData = { lib = 'missfinale_c2ig_11', anim = 'pushcar_offcliff_f' }
local DetachKeys = { 157, 158, 160, 164, 165, 73, 36, 44 }
local RECENT_PED_CLEAR_INTERVAL = 30000 -- Clear recent peds after 30 seconds
local UI_UPDATE_INTERVAL = 1000 -- Update UI every second
local THREAD_UPDATE_INTERVAL = 0 -- Poll interaction inputs every frame to avoid missing just-pressed keys
local THREAD_SLOW_UPDATE_INTERVAL = 250 -- Slow thread update interval

-- PolyZone Configuration
local ZoneConfig = {
    GrabZone = { size = 1.2, offset = { x = 1.0, y = 0.0, z = 1.0 } }, -- Grab zone size and offset from stand
    PrepareZone = { size = 1.5, offset = { x = 0.0, y = 0.0, z = 1.0 } }, -- Prepare zone size and offset (increased for better detection)
    SellingZone = { size = 15.0, offset = { x = 0.0, y = -0.8, z = 1.0 } }, -- Selling zone radius
}

-- Entity Attachment Offsets (for props attached to ped bones)
local AttachmentOffsets = {
    Spatel = { x = 0.08, y = 0.0, z = -0.02, rotX = 0.0, rotY = -25.0, rotZ = 130.0 }, -- Spatel object (cooking utensil)
    Stand = { x = -0.45, y = -1.2, z = -0.82, rotX = 180.0, rotY = 180.0, rotZ = 270.0 }, -- Hotdog stand when pushing
    Hotdog = { x = 0.12, y = 0.0, z = -0.05, rotX = 220.0, rotY = 120.0, rotZ = 0.0 }, -- Hotdog object when selling
}

-- Bone Indices (for entity attachments)
local BoneIndices = {
    Hand = 57005, -- Left hand bone index
    Stand = 28422, -- Bone index for pushing stand
}

-- Helper Functions (defined early so they can be used by other functions)
local function CleanupEntity(entity)
    if entity and DoesEntityExist(entity) then
        DeleteEntity(entity)
    end
end

-- Strip color codes from text (for qb-core DrawText which doesn't support colors)
function StripColorCodes(text)
    local cleaned = tostring(text)
    cleaned = cleaned:gsub("~%a~", "") -- Remove all color codes (~g~, ~r~, ~s~, etc.)
    cleaned = cleaned:gsub("%[", "") -- Remove opening brackets
    cleaned = cleaned:gsub("%]", "") -- Remove closing brackets
    cleaned = cleaned:gsub("^%s+", ""):gsub("%s+$", "") -- Trim whitespace
    return cleaned
end

local function HideText()
    if Config.TextDisplayType == 'qb-core' then
        exports['qb-core']:HideText()
    elseif Config.TextDisplayType == 'html' then
        SendNUIMessage({ action = 'HideTextPrompt' })
    else
        CurrentTextPrompt, CurrentTextCoords = nil, nil
    end
end

local function MarkPedRecently(ped)
    SellingData.RecentPeds[ped] = true
end

local function CleanupSellingTarget()
    if SellingData.Target and DoesEntityExist(SellingData.Target) then
        SetPedKeepTask(SellingData.Target, false)
        SetEntityAsNoLongerNeeded(SellingData.Target)
        ClearPedTasksImmediately(SellingData.Target)
        MarkPedRecently(SellingData.Target)
    end
    CurrentSellPrompt = nil
    SellingData.Enabled, SellingData.Target, SellingData.HasTarget, SellingData.Hotdog = false, nil, false, nil
    SellingData.Personality, SellingData.DemandMultiplier, SellingData.DemandLabel = nil, 1.0, 'default'
end

-- Text Display Functions
local function HideTextPrompt()
    if not IsTextVisible then return end
    IsTextVisible, TextState = false, nil
    HideText()
end

-- PolyZone Management Functions
local function CleanupStandZones()
    for zoneName, zone in pairs(StandZones) do
        if zone then zone:destroy() end
        StandZones[zoneName] = nil
    end
    for zoneName in pairs(InStandZones) do
        InStandZones[zoneName] = false
    end
end

local function CreateStandZones()
    if not StandObject or not DoesEntityExist(StandObject) then return end

    CleanupStandZones() -- Clean up any existing zones first

    local standHeading = GetEntityHeading(StandObject)

    -- Create Grab Zone (at the back/side of stand)
    local grabOffset = ZoneConfig.GrabZone.offset
    local grabPos = GetOffsetFromEntityInWorldCoords(StandObject, grabOffset.x, grabOffset.y, grabOffset.z)
    StandZones.GrabZone = BoxZone:Create(vector3(grabPos.x, grabPos.y, grabPos.z),
        ZoneConfig.GrabZone.size, ZoneConfig.GrabZone.size, {
            name = 'hotdog_grab_zone',
            debugPoly = false,
            minZ = grabPos.z - 0.5,
            maxZ = grabPos.z + 2.0,
            heading = standHeading,
        })

    -- Create Prepare Zone (in front of stand)
    local prepOffset = ZoneConfig.PrepareZone.offset
    local prepPos = GetOffsetFromEntityInWorldCoords(StandObject, prepOffset.x, prepOffset.y, prepOffset.z)
    StandZones.PrepareZone = BoxZone:Create(vector3(prepPos.x, prepPos.y, prepPos.z),
        ZoneConfig.PrepareZone.size, ZoneConfig.PrepareZone.size, {
            name = 'hotdog_prepare_zone',
            debugPoly = false,
            minZ = prepPos.z - 0.5,
            maxZ = prepPos.z + 2.0,
            heading = standHeading,
        })

    -- Create Selling Zone (around the stand for customer detection)
    local sellOffset = ZoneConfig.SellingZone.offset
    local sellPos = GetOffsetFromEntityInWorldCoords(StandObject, sellOffset.x, sellOffset.y, sellOffset.z)
    StandZones.SellingZone = CircleZone:Create(vector3(sellPos.x, sellPos.y, sellPos.z),
        ZoneConfig.SellingZone.size, {
            name = 'hotdog_selling_zone',
            debugPoly = false,
            useZ = true,
        })

    -- Grab Zone Callbacks
    StandZones.GrabZone:onPlayerInOut(function(isPointInside)
        InStandZones.Grab = isPointInside
        if not isPointInside then
            -- Always try to hide when leaving grab zone (dedicated thread will prevent if still in prepare zone)
            HideTextPrompt()
        end
    end)

    -- Prepare Zone Callbacks
    StandZones.PrepareZone:onPlayerInOut(function(isPointInside)
        InStandZones.Prepare = isPointInside
        if isPointInside then
            -- Show text immediately when entering zone
            local currentSellingState = SellingData.Enabled
            LastSellingState = currentSellingState
        else
            -- Always try to hide when leaving prepare zone (dedicated thread will prevent if still in grab zone)
            HideTextPrompt()
            LastSellingState = nil
        end
    end)
end

-- Resource Cleanup
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        CleanupStandZones()
        CleanupEntity(StandObject)
        CleanupEntity(SpatelObject)
        CleanupEntity(HotdogObject)
        ClearPedTasksImmediately(PlayerPedId())
        SendNUIMessage({ action = 'UpdateUI', IsActive = false })
        SendNUIMessage({ action = 'HideTextPrompt' }) -- Hide HTML text prompt if active
        if HotdogBlip then RemoveBlip(HotdogBlip) end
        CleanupSellingTarget()
        SetNuiFocus(false, false)
        IsWorking, IsPushing, IsUIActive, PreparingFood = false, false, false, false
        SellingData.RecentPeds = {}
        exports['qb-core']:HideText()
    end
end)

RegisterNUICallback('minigameResult', function(data, cb)
    if not HTMLMinigamePending then
        cb('ok')
        return
    end

    HTMLMinigameResult = {
        quit = not not (data and data.quit),
        faults = (data and tonumber(data.faults)) or 2,
    }
    HTMLMinigamePending = false
    SetNuiFocus(false, false)
    cb('ok')
end)

-- Utility Functions
local function LoadAnim(dict)
    while not HasAnimDictLoaded(dict) do RequestAnimDict(dict) Wait(1) end
end

local function LoadModel(model)
    while not HasModelLoaded(model) do RequestModel(model) Wait(1) end
end

local function HasRequiredJob()
    if not Config.RequireJob then return true end
    return PlayerData and PlayerData.job and PlayerData.job.name == Config.JobName
end

local function UpdateLevel()
    local MyRep = (PlayerData.metadata and PlayerData.metadata['rep'] and PlayerData.metadata['rep']['hotdog']) or 0
    local thresholds = Config.ReputationThresholds or { [1] = 0, [2] = 50, [3] = 100, [4] = 200 }

    -- Calculate level based on reputation thresholds (more maintainable)
    if MyRep >= thresholds[4] then
        Config.MyLevel = 4
    elseif MyRep >= thresholds[3] then
        Config.MyLevel = 3
    elseif MyRep >= thresholds[2] then
        Config.MyLevel = 2
    else
        Config.MyLevel = 1
    end

    return { lvl = Config.MyLevel, rep = MyRep }
end

local function DrawText3D(coords, text)
    if not Config.ShowTextPrompts or Config.TextDisplayType ~= '3d' then return end
    local coordsX, coordsY, coordsZ = coords.x or 0, coords.y or 0, coords.z or 0
    local onScreen, _x, _y = World3dToScreen2d(coordsX, coordsY, coordsZ)
    if not onScreen then return end

    -- Strip GTA color codes from text (e.g., ~g~, ~r~, ~b~, ~s~, etc.)
    local cleanText = text:gsub("~%a~", "")

    local distance = #(GetGameplayCamCoord() - vector3(coordsX, coordsY, coordsZ))
    local scale = ((1 / distance) * 2) * ((1 / GetGameplayCamFov()) * 100)

    SetTextScale(0.0 * scale, 0.35 * scale)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(2, 0, 0, 0, 150)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentSubstringPlayerName(cleanText)
    DrawText(_x, _y)
end

-- 3D Text Render Thread (adaptive wait)
if Config.TextDisplayType == '3d' then
    CreateThread(function()
        while true do
            if CurrentTextPrompt and CurrentTextCoords then
                DrawText3D(CurrentTextCoords, CurrentTextPrompt)
                Wait(0)
            else
                Wait(250)
            end
        end
    end)
end

-- Blip Management
local function UpdateBlip()
    if HasRequiredJob() then
        if HotdogBlip then RemoveBlip(HotdogBlip) end
        local coords = Config.Locations['take'].coords
        HotdogBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(HotdogBlip, 542)
        SetBlipDisplay(HotdogBlip, 4)
        SetBlipScale(HotdogBlip, 0.6)
        SetBlipAsShortRange(HotdogBlip, true)
        SetBlipColour(HotdogBlip, 17)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(Lang:t('info.blip_name'))
        EndTextCommandSetBlipName(HotdogBlip)
    elseif HotdogBlip then
        RemoveBlip(HotdogBlip)
        HotdogBlip = nil
    end
end

-- Hotdog Functions
local function GetAvailableHotdog()
    if not Config.Stock then return nil end
    local available = {}
    for k, v in pairs(Config.Stock) do
        if v and v.Current and v.Current > 0 then
            available[#available + 1] = k
        end
    end
    return #available > 0 and available[math.random(1, #available)] or nil
end

local function GetCookOutcome(faults)
    local f = tonumber(faults) or 99
    local outcomeCfg = Config.CookingOutcomes or {}
    local perfectMax = outcomeCfg.PerfectMaxFaults or 0
    local goodMax = outcomeCfg.GoodMaxFaults or 1
    local undercookedMax = outcomeCfg.UndercookedMaxFaults or 2

    if f <= perfectMax then
        return 'perfect', 'exotic'
    elseif f <= goodMax then
        return 'good', 'rare'
    elseif f <= undercookedMax then
        return 'undercooked', 'common'
    end

    return 'burnt', nil
end

local function GetDemandMultiplier()
    local demandTable = Config.DemandByHour
    if type(demandTable) ~= 'table' then
        return 1.0, 'default'
    end

    local hour = GetClockHours()
    for _, period in ipairs(demandTable) do
        local startHour = tonumber(period.StartHour) or 0
        local endHour = tonumber(period.EndHour) or 24
        local inRange

        if startHour <= endHour then
            inRange = hour >= startHour and hour < endHour
        else
            -- Overnight range (e.g. 22 -> 3)
            inRange = hour >= startHour or hour < endHour
        end

        if inRange then
            return tonumber(period.Multiplier) or 1.0, period.Label or 'demand'
        end
    end

    return 1.0, 'default'
end

local function PickCustomerPersonality()
    local personalities = Config.CustomerPersonalities
    if type(personalities) ~= 'table' or #personalities == 0 then
        return {
            Name = 'normal',
            Weight = 1,
            PriceMultiplier = 1.0,
            AmountMultiplier = 1.0,
            RejectChance = 0.1,
        }
    end

    local totalWeight = 0
    for _, personality in ipairs(personalities) do
        totalWeight = totalWeight + math.max(tonumber(personality.Weight) or 0, 0)
    end

    if totalWeight <= 0 then
        return personalities[1]
    end

    local roll = math.random() * totalWeight
    local cumulative = 0
    for _, personality in ipairs(personalities) do
        cumulative = cumulative + math.max(tonumber(personality.Weight) or 0, 0)
        if roll <= cumulative then
            return personality
        end
    end

    return personalities[#personalities]
end

local function UpdateUI()
    IsUIActive = true
    CreateThread(function()
        while IsUIActive do
            if StandObject and DoesEntityExist(StandObject) then
                local canRelease = IsPushing
                local canGrab = false
                local canPrepare = not IsPushing and InStandZones.Prepare

                if not IsPushing then
                    if Config.UseTarget then
                        local playerPos = GetEntityCoords(PlayerPedId())
                        local standPos = GetEntityCoords(StandObject)
                        canGrab = #(playerPos - standPos) <= 3.0
                    else
                        canGrab = InStandZones.Grab
                    end
                end

                local controls = {
                    Grab = Lang:t('info.grab_stall'),
                    Release = Lang:t('info.drop_stall'),
                    Prepare = Lang:t('info.prepare'),
                    Sell = CurrentSellPrompt,
                    IsPushing = IsPushing,
                    IsSelling = SellingData.Enabled,
                    ShowGrab = canGrab,
                    ShowRelease = canRelease,
                    ShowPrepare = canPrepare,
                    ShowSell = CurrentSellPrompt ~= nil,
                }
                SendNUIMessage({
                    action = 'UpdateUI',
                    IsActive = IsUIActive,
                    Stock = Config.Stock,
                    Level = UpdateLevel(),
                    Controls = controls,
                    Settings = {
                        UISounds = Config.UISounds,
                    },
                })
            else
                -- Stand doesn't exist, hide UI
                IsUIActive = false
                SendNUIMessage({ action = 'UpdateUI', IsActive = false })
                break
            end
            Wait(UI_UPDATE_INTERVAL)
        end
    end)
end

local function LetKraamLose()
    if StandObject and DoesEntityExist(StandObject) then
        DetachEntity(StandObject)
        SetEntityCollision(StandObject, true, true)
        -- Recreate zones when dropping stand
        if IsWorking then
            CreateStandZones()
        end
    end
    ClearPedTasks(PlayerPedId())
    IsPushing = false
end

-- Utility helpers
local function ClearSellingTarget(ped, notifyKey, notifyType, notifyParams)
    if ped and DoesEntityExist(ped) then
        FreezeEntityPosition(ped, false)
        SetPedKeepTask(ped, false)
        SetEntityAsNoLongerNeeded(ped)
        ClearPedTasksImmediately(ped)
        MarkPedRecently(ped)
    end
    if notifyKey then QBCore.Functions.Notify(Lang:t(notifyKey, notifyParams or {}), notifyType or 'error') end
    CurrentSellPrompt = nil
    SellingData.Target, SellingData.HasTarget, SellingData.Hotdog = nil, false, nil
end

local function StartActiveLoops()
    if ActiveLoopsStarted then return end
    ActiveLoopsStarted = true

    -- Cleanup recent peds while job is active.
    CreateThread(function()
        while IsWorking do
            Wait(RECENT_PED_CLEAR_INTERVAL)
            if next(SellingData.RecentPeds) then
                SellingData.RecentPeds = {}
            end
        end
    end)

    -- Hide text when the player drifts out of interaction range/zones.
    CreateThread(function()
        while IsWorking do
            if StandObject and DoesEntityExist(StandObject) and not IsPushing then
                local playerPos = GetEntityCoords(PlayerPedId())
                local standPos = GetEntityCoords(StandObject)
                local distanceFromStand = #(playerPos - standPos)
                local isInAnyZone = InStandZones.Prepare or InStandZones.Grab

                if IsTextVisible and (not isInAnyZone or distanceFromStand > 3.5) then
                    HideTextPrompt()
                end
                Wait(100)
            else
                Wait(THREAD_SLOW_UPDATE_INTERVAL)
            end
        end
    end)

    -- Disable unrelated controls while pushing.
    CreateThread(function()
        while IsWorking do
            if IsPushing then
                DisableControlAction(0, 244) -- m
                DisableControlAction(0, 23)  -- f
                Wait(0)
            else
                Wait(THREAD_SLOW_UPDATE_INTERVAL)
            end
        end
    end)

    -- Drop stand on unsafe/blocked actions while pushing.
    CreateThread(function()
        while IsWorking do
            if IsPushing then
                for _, key in pairs(DetachKeys) do
                    if IsControlJustPressed(0, key) or IsDisabledControlJustPressed(0, key) then
                        LetKraamLose()
                    end
                end

                local ped = PlayerPedId()
                if IsPedShooting(ped) or IsPlayerFreeAiming(PlayerId()) or IsPedInMeleeCombat(ped) or IsPedDeadOrDying(ped, false) or IsPedRagdoll(ped) then
                    LetKraamLose()
                end
            end
            Wait(5)
        end
    end)
end

-- Animation Functions
local function PrepareAnim()
    local ped = PlayerPedId()
    LoadAnim('amb@prop_human_bbq@male@idle_a')
    TaskPlayAnim(ped, 'amb@prop_human_bbq@male@idle_a', 'idle_b', 6.0, -6.0, -1, 47, 0, 0, 0, 0)
    SpatelObject = CreateObject(`prop_fish_slice_01`, 0, 0, 0, true, true, true)
    local spatelOffset = AttachmentOffsets.Spatel
    AttachEntityToEntity(SpatelObject, ped, GetPedBoneIndex(ped, BoneIndices.Hand),
        spatelOffset.x, spatelOffset.y, spatelOffset.z,
        spatelOffset.rotX, spatelOffset.rotY, spatelOffset.rotZ,
        true, true, false, true, 1, true)
    PreparingFood = true

    CreateThread(function()
        while PreparingFood do
            Wait(0) -- linter friendly wait
            local localPed = PlayerPedId()
            if not IsEntityPlayingAnim(localPed, 'amb@prop_human_bbq@male@idle_a', 'idle_b', 3) then
                LoadAnim('amb@prop_human_bbq@male@idle_a')
                TaskPlayAnim(localPed, 'amb@prop_human_bbq@male@idle_a', 'idle_b', 6.0, -6.0, -1, 49, 0, 0, 0, 0)
            end
            Wait(200)
        end
        if SpatelObject and DoesEntityExist(SpatelObject) then
            DetachEntity(SpatelObject)
            DeleteEntity(SpatelObject)
        end
        ClearPedTasksImmediately(PlayerPedId())
    end)
end

local function TakeHotdogStand()
    if not StandObject or not DoesEntityExist(StandObject) then return end
    local PlayerPed = PlayerPedId()
    IsPushing = true

    -- Clean up zones when picking up stand (zones are static and won't work when stand moves)
    CleanupStandZones()

    NetworkRequestControlOfEntity(StandObject)
    LoadAnim(AnimationData.lib)
    TaskPlayAnim(PlayerPed, AnimationData.lib, AnimationData.anim, 8.0, 8.0, -1, 50, 0, false, false, false)
    SetTimeout(150, function()
        if StandObject and DoesEntityExist(StandObject) then
            local standOffset = AttachmentOffsets.Stand
            AttachEntityToEntity(StandObject, PlayerPed, GetPedBoneIndex(PlayerPed, BoneIndices.Stand),
                standOffset.x, standOffset.y, standOffset.z,
                standOffset.rotX, standOffset.rotY, standOffset.rotZ,
                false, false, false, false, 1, true)
        end
    end)
    FreezeEntityPosition(StandObject, false)
    FreezeEntityPosition(PlayerPed, false)

    CreateThread(function()
        while IsPushing do
            Wait(0) -- linter friendly wait
            local localPed = PlayerPedId()
            if not IsEntityPlayingAnim(localPed, AnimationData.lib, AnimationData.anim, 3) then
                LoadAnim(AnimationData.lib)
                TaskPlayAnim(localPed, AnimationData.lib, AnimationData.anim, 8.0, 8.0, -1, 50, 0, false, false, false)
            end
            Wait(1000)
        end
    end)
end

local function FinishMinigame(faults)
    local outcome, Quality = GetCookOutcome(faults)

    if outcome == 'burnt' or not Quality then
        PreparingFood = false
        QBCore.Functions.Notify('You burned the hotdog and had to throw it away.', 'error')
        return
    end

    if not Config.Stock or not Config.Stock[Quality] or not Config.Stock[Quality].Max or not Config.Stock[Quality].Max[Config.MyLevel] then
        PreparingFood = false
        return
    end

    local stockData = Config.Stock[Quality]
    local MaxStock = stockData.Max[Config.MyLevel]
    if not MaxStock or MaxStock <= 0 then
        PreparingFood = false
        return
    end

    if (stockData.Current or 0) + 1 <= MaxStock then
        TriggerServerEvent('qb-hotdogjob:server:UpdateReputation', Quality)
        local currentStock = stockData.Current or 0
        local increment
        if outcome == 'undercooked' then
            increment = 1
        else
            increment = Config.MyLevel == 1 and 1 or (math.random(1, 2) == math.random(1, 2) and math.min(math.random(1, Config.MyLevel), MaxStock - currentStock) or 1)
        end
        local amount = math.min(currentStock + increment, MaxStock)
        local made = amount - currentStock
        stockData.Current = amount
        local label = stockData.Label or Quality
        QBCore.Functions.Notify(made > 1 and Lang:t('success.made_luck_hotdog', { value = made, value2 = label }) or Lang:t('success.made_hotdog', { value = label }), 'success')
    else
        local label = stockData.Label or Quality
        QBCore.Functions.Notify(Lang:t('error.no_more', { value = label }), 'error')
    end
    PreparingFood = false
end

local function DrawBuiltInMinigameText(text, y, scale)
    y = y or 0.86
    scale = scale or 0.36
    SetTextFont(4)
    SetTextProportional(1)
    SetTextScale(scale, scale)
    SetTextColour(255, 255, 255, 215)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(2, 0, 0, 0, 150)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry('STRING')
    SetTextCentre(1)
    AddTextComponentSubstringPlayerName(text)
    DrawText(0.5, y)
end

local function DrawBuiltInMinigameBar(heat, windowStart, windowEnd)
    local barX, barY = 0.5, 0.905
    local barW, barH = 0.24, 0.017

    local windowCenter = (windowStart + windowEnd) * 0.5
    local windowWidth = math.max(windowEnd - windowStart, 0.01)
    local cursorWidth = 0.004

    local windowX = barX - (barW * 0.5) + (windowCenter * barW)
    local windowW = windowWidth * barW
    local cursorX = barX - (barW * 0.5) + (heat * barW)

    -- Bar background
    DrawRect(barX, barY, barW, barH, 25, 25, 25, 220)
    -- Perfect cook window
    DrawRect(windowX, barY, windowW, barH, 60, 190, 90, 200)
    -- Temperature cursor
    DrawRect(cursorX, barY, cursorWidth, barH + 0.006, 255, 255, 255, 235)
end

local function RunBuiltInMinigame()
    local settings = (Config.Minigame and Config.Minigame.BuiltIn) or {}
    local rounds = settings.Rounds or 4
    local timePerRoundMs = settings.TimePerRoundMs or 2200
    local maxFaults = settings.MaxFaults or 2

    local faults = 0

    for round = 1, rounds do
        local windowWidth = math.max(0.22 - ((round - 1) * 0.03), 0.11)
        local windowCenter = math.random() * (1.0 - windowWidth) + (windowWidth * 0.5)
        local windowStart = windowCenter - (windowWidth * 0.5)
        local windowEnd = windowCenter + (windowWidth * 0.5)

        local heat = math.random()
        local direction = math.random(0, 1) == 0 and -1 or 1
        local speed = 0.75 + (math.random() * 0.55)

        local endAt = GetGameTimer() + timePerRoundMs
        local roundResolved = false
        local lastTick = GetGameTimer()

        while GetGameTimer() < endAt do
            Wait(0)

            local now = GetGameTimer()
            local dt = (now - lastTick) / 1000.0
            lastTick = now

            heat = heat + (direction * speed * dt)
            if heat <= 0.0 then
                heat = 0.0
                direction = 1
            elseif heat >= 1.0 then
                heat = 1.0
                direction = -1
            end

            local remainingMs = math.max(endAt - GetGameTimer(), 0)
            local remainingSec = math.ceil(remainingMs / 1000)
            DrawBuiltInMinigameText(string.format('COOKING  %d/%d   PRESS [E] IN GREEN ZONE', round, rounds), 0.86, 0.33)
            DrawBuiltInMinigameText(string.format('TIME: %ds   FAULTS: %d/%d', remainingSec, faults, maxFaults), 0.878, 0.30)
            DrawBuiltInMinigameBar(heat, windowStart, windowEnd)

            if IsControlJustPressed(0, 38) or IsDisabledControlJustPressed(0, 38) then
                if heat >= windowStart and heat <= windowEnd then
                    PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
                else
                    faults = faults + 1
                    PlaySoundFrontend(-1, 'ERROR', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
                end
                roundResolved = true
                break
            end
        end

        if not roundResolved then
            faults = faults + 1
            PlaySoundFrontend(-1, 'ERROR', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
            if faults > maxFaults then
                return { quit = true, faults = faults }
            end
        elseif faults > maxFaults then
            return { quit = true, faults = faults }
        end
    end

    return { quit = false, faults = faults }
end

local function RunQBMinigame()
    local ok, result = pcall(function()
        return exports['qb-minigames']:KeyMinigame(10)
    end)

    if not ok then
        return nil, false
    end

    if type(result) ~= 'table' then
        return { quit = true, faults = 2 }, true
    end

    return { quit = result.quit, faults = result.faults or 2 }, true
end

local function RunHTMLMinigame()
    local settings = (Config.Minigame and Config.Minigame.HTML) or {}
    local rounds = settings.Rounds or 4
    local timePerRoundMs = settings.TimePerRoundMs or 2200
    local maxFaults = settings.MaxFaults or 2

    HTMLMinigamePending = true
    HTMLMinigameResult = nil

    SetNuiFocus(true, false)
    SendNUIMessage({
        action = 'StartCookingMinigame',
        Config = {
            Rounds = rounds,
            TimePerRoundMs = timePerRoundMs,
            MaxFaults = maxFaults,
            ComboBonusEvery = settings.ComboBonusEvery or 3,
            BaseWindow = settings.BaseWindow or 0.22,
            WindowStep = settings.WindowStep or 0.03,
            MinWindow = settings.MinWindow or 0.11,
            HeatSpeedMin = settings.HeatSpeedMin or 0.75,
            HeatSpeedMax = settings.HeatSpeedMax or 1.3,
        },
    })

    local timeoutAt = GetGameTimer() + (rounds * timePerRoundMs) + 5000
    while HTMLMinigamePending and GetGameTimer() < timeoutAt do
        Wait(0)
    end

    if HTMLMinigamePending then
        HTMLMinigamePending = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'StopCookingMinigame' })
        return { quit = true, faults = maxFaults + 1 }, false
    end

    if not HTMLMinigameResult then
        return { quit = true, faults = maxFaults + 1 }, false
    end

    return HTMLMinigameResult, true
end

local function StartHotdogMinigame()
    if PreparingFood then
        QBCore.Functions.Notify(Lang:t('error.already_preparing'), 'error')
        return
    end

    PrepareAnim()

    local provider = (Config.Minigame and Config.Minigame.Provider) or 'auto'
    local result

    if provider == 'builtin' then
        result = RunBuiltInMinigame()
    elseif provider == 'html' then
        local htmlResult, ok = RunHTMLMinigame()
        if not ok then
            PreparingFood = false
            QBCore.Functions.Notify(Lang:t('error.minigame_unavailable'), 'error')
            return
        end
        result = htmlResult
    elseif provider == 'qb-minigames' then
        local qbResult, ok = RunQBMinigame()
        if not ok then
            PreparingFood = false
            QBCore.Functions.Notify(Lang:t('error.minigame_unavailable'), 'error')
            return
        end
        result = qbResult
    else
        local qbResult, ok = RunQBMinigame()
        if ok then
            result = qbResult
        else
            local htmlResult, htmlOk = RunHTMLMinigame()
            result = htmlOk and htmlResult or RunBuiltInMinigame()
        end
    end

    if result then
        if not result.quit then
            FinishMinigame(result.faults or 2)
        else
            local outcome = GetCookOutcome(result.faults or 99)
            if outcome == 'burnt' then
                FinishMinigame(result.faults or 99)
            else
                PreparingFood = false
            end
        end
    else
        PreparingFood = false
    end
end

-- Stand Interaction Loop (Using PolyZone callbacks)
local function StandInteractionLoop()
    -- Create zones when stand is spawned
    CreateStandZones()

    -- Input handling thread for zone-based interactions
    CreateThread(function()
        while IsWorking and StandObject do
            Wait(0)

            -- Handle dropping stand when pushing (works anywhere, not just in zones)
            if IsPushing then
                if IsControlJustPressed(0, 47) or IsDisabledControlJustPressed(0, 47) then -- G key
                    LetKraamLose()
                    HideTextPrompt()
                end
            -- Handle Grab Zone interactions (only when not pushing)
            elseif InStandZones.Grab then
                if IsControlJustPressed(0, 47) or IsDisabledControlJustPressed(0, 47) then
                    HideTextPrompt()
                    CleanupSellingTarget()
                    TakeHotdogStand()
                end
            end

            -- Handle Prepare Zone interactions (only when not pushing)
            -- Check prepare zone independently - prepare takes priority over grab
            if not IsPushing and StandObject and DoesEntityExist(StandObject) then

                -- Check if in prepare zone (only use PolyZone, not distance fallback to avoid conflicts)
                if InStandZones.Prepare then
                    -- Always show text when in prepare area
                    local currentSellingState = SellingData.Enabled
                    local prepText = currentSellingState and Lang:t('info.selling_prep') or Lang:t('info.not_selling')

                    -- Always show text when in prepare zone - update if state changed or not visible
                    if LastSellingState ~= currentSellingState or not IsTextVisible or TextState ~= tostring(prepText) then
                        LastSellingState = currentSellingState
                    end

                    -- Handle prepare interaction (E key)
                    if IsControlJustPressed(0, 38) or IsDisabledControlJustPressed(0, 38) then
                        HideTextPrompt()
                        StartHotdogMinigame()
                    end
                -- Handle Grab Zone interactions only if not in prepare area
                elseif InStandZones.Grab then
                    if IsControlJustPressed(0, 47) or IsDisabledControlJustPressed(0, 47) then
                        HideTextPrompt()
                        CleanupSellingTarget()
                        TakeHotdogStand()
                    end
                end
            end

            Wait(THREAD_UPDATE_INTERVAL)
        end
    end)
end

-- Work Management
local function StartWorking()
    if Config.RequireJob and not HasRequiredJob() then
        QBCore.Functions.Notify('You do not have the required job to use this!', 'error')
        return
    end

    QBCore.Functions.TriggerCallback('qb-hotdogjob:server:HasMoney', function(HasMoney)
        if not HasMoney then
            QBCore.Functions.Notify(Lang:t('error.no_money'), 'error')
            return
        end

        local SpawnCoords = Config.Locations['spawn'].coords
        IsWorking = true
        LoadModel('prop_hotdogstand_01')
        StandObject = CreateObject(`prop_hotdogstand_01`, SpawnCoords.x, SpawnCoords.y, SpawnCoords.z, true)
        PlaceObjectOnGroundProperly(StandObject)
        SetEntityHeading(StandObject, SpawnCoords.w - 90)
        FreezeEntityPosition(StandObject, true)
        StartActiveLoops()

        -- Create zones for stand interactions
        CreateStandZones()

        if Config.UseTarget then
            exports['qb-target']:AddTargetEntity(StandObject, {
                options = {
                    {
                        icon = 'fas fa-hand',
                        label = Lang:t('info.grab'),
                        canInteract = function() return IsWorking end,
                        action = function()
                            if not IsPushing then
                                CleanupSellingTarget()
                                TakeHotdogStand()
                            else
                                LetKraamLose()
                            end
                        end
                    },
                    {
                        icon = 'fas fa-hotdog',
                        label = Lang:t('info.prepare'),
                        canInteract = function() return IsWorking end,
                        action = function()
                            if not IsPushing then StartHotdogMinigame() end
                        end
                    },
                    {
                        icon = 'fas fa-hand-holding-usd',
                        label = Lang:t('info.toggle_sell'),
                        type = 'client',
                        event = 'qb-hotdogjob:client:ToggleSell',
                        canInteract = function() return IsWorking end
                    }
                },
                distance = 3.0
            })
        else
            StandInteractionLoop()
        end

        UpdateUI()
        QBCore.Functions.Notify(Lang:t('success.deposit', { deposit = Config.StandDeposit }), 'success')
    end)
end

local function StopWorking()
    HideTextPrompt()
    CleanupStandZones()
    if SellingData.Enabled then CleanupSellingTarget() end
    IsUIActive = false
    SendNUIMessage({ action = 'UpdateUI', IsActive = false })

    if StandObject and DoesEntityExist(StandObject) then
        QBCore.Functions.TriggerCallback('qb-hotdogjob:server:BringBack', function(DidBail)
            if DidBail then
                DeleteObject(StandObject)
                StandObject = nil
                ClearPedTasksImmediately(PlayerPedId())
                QBCore.Functions.Notify(Lang:t('success.deposit_returned', { deposit = Config.StandDeposit }), 'success')
            else
                QBCore.Functions.Notify(Lang:t('error.deposit_notreturned'), 'error')
            end
        end)
    else
        QBCore.Functions.Notify(Lang:t('error.no_stand_found'), 'error')
    end

    -- Reset states
    IsWorking = false
    IsPushing = false
    ActiveLoopsStarted = false
    CurrentSellPrompt = nil

    -- Reset stock
    for _, v in pairs(Config.Stock) do
        if v then v.Current = 0 end
    end
end

-- Selling Functions
local function CalculateSaleAmount(hotdogType)
    if not hotdogType or not Config.Stock[hotdogType] then return 0, 0 end
    local stock = Config.Stock[hotdogType]
    local personality = SellingData.Personality or { PriceMultiplier = 1.0, AmountMultiplier = 1.0 }
    local demandMultiplier = SellingData.DemandMultiplier or 1.0

    local amount = stock.Current >= 3 and math.random(1, 3) or (stock.Current > 1 and math.random(1, stock.Current) or 1)
    local amountMultiplier = tonumber(personality.AmountMultiplier) or 1.0
    amount = math.max(1, math.floor((amount * amountMultiplier) + 0.5))
    amount = math.min(amount, 3)
    amount = math.min(amount, stock.Current)

    local basePrice = stock.Price[Config.MyLevel] and math.random(stock.Price[Config.MyLevel].min, stock.Price[Config.MyLevel].max) or 0
    local priceMultiplier = tonumber(personality.PriceMultiplier) or 1.0
    local finalMultiplier = priceMultiplier * demandMultiplier
    local price = math.max(1, math.floor((basePrice * finalMultiplier) + 0.5))

    return amount, price
end

local function BuildOfferContextText()
    local personalityName = (SellingData.Personality and SellingData.Personality.Name) or 'normal'
    local demandLabel = SellingData.DemandLabel or 'default'
    local demandMultiplier = SellingData.DemandMultiplier or 1.0

    local prettyPersonality = personalityName:gsub('^%l', string.upper)
    local prettyDemand = demandLabel:gsub('[-_]', ' '):gsub('^%l', string.upper)

    local demandColor = '~c~'
    if demandMultiplier > 1.05 then
        demandColor = '~g~'
    elseif demandMultiplier < 0.95 then
        demandColor = '~r~'
    end

    local demandDelta = math.floor(((demandMultiplier - 1.0) * 100) + 0.5)
    local deltaPrefix = demandDelta >= 0 and '+' or ''

    return ('~c~[%s | %s %sx%.2f (%s%d%%)]~s~'):format(prettyPersonality, prettyDemand, demandColor, demandMultiplier, deltaPrefix, demandDelta)
end

local function BuildOfferContextTargetText()
    local personalityName = (SellingData.Personality and SellingData.Personality.Name) or 'normal'
    local demandLabel = SellingData.DemandLabel or 'default'
    local demandMultiplier = SellingData.DemandMultiplier or 1.0

    local prettyPersonality = personalityName:gsub('^%l', string.upper)
    local prettyDemand = demandLabel:gsub('[-_]', ' '):gsub('^%l', string.upper)
    local demandDelta = math.floor(((demandMultiplier - 1.0) * 100) + 0.5)
    local deltaPrefix = demandDelta >= 0 and '+' or ''

    return ('[%s | %s x%.2f (%s%d%%)]'):format(prettyPersonality, prettyDemand, demandMultiplier, deltaPrefix, demandDelta)
end

local function SellToPed(ped)
    if not StandObject or not DoesEntityExist(StandObject) then return end
    if not ped or not DoesEntityExist(ped) then return end
    CurrentSellPrompt = nil

    -- Skip if ped was recently interacted with
    if SellingData.RecentPeds and SellingData.RecentPeds[ped] then
        SellingData.HasTarget = false
        return
    end

    SellingData.HasTarget = true
    SetEntityAsNoLongerNeeded(ped)
    ClearPedTasks(ped)

    SellingData.Hotdog = GetAvailableHotdog()
    if not SellingData.Hotdog then
        SellingData.HasTarget = false
        CurrentSellPrompt = nil
        -- Prevent notification spam with cooldown (5 seconds)
        local currentTime = GetGameTimer()
        if currentTime - LastNoDogsNotify > 5000 then
            QBCore.Functions.Notify(Lang:t('error.no_dogs'), 'error')
            LastNoDogsNotify = currentTime
            -- Stop selling if no hotdogs available
            if SellingData.Enabled then
                SellingData.Enabled = false
                if SellingData.Target then
                    ClearSellingTarget(SellingData.Target)
                end
            end
        end
        return
    end

    SellingData.Personality = PickCustomerPersonality()
    local demandMultiplier, demandLabel = GetDemandMultiplier()
    SellingData.DemandMultiplier = demandMultiplier
    SellingData.DemandLabel = demandLabel

    local HotdogsForSale, SellingPrice = CalculateSaleAmount(SellingData.Hotdog)
    local coords = GetOffsetFromEntityInWorldCoords(StandObject, OffsetData.x, OffsetData.y, OffsetData.z)
    local pedCoords = GetEntityCoords(ped)
    local pedDist = #(coords - pedCoords)

    TaskGoStraightToCoord(ped, coords, 1.2, -1, 0.0, 0.0)

    -- Wait for ped to arrive
    while pedDist > OffsetData.Distance do
        Wait(0) -- linter friendly wait
        local playerCoords = GetEntityCoords(PlayerPedId())
        coords = GetOffsetFromEntityInWorldCoords(StandObject, OffsetData.x, OffsetData.y, OffsetData.z)
        local PlayerDist = #(playerCoords - coords)
        pedCoords = GetEntityCoords(ped)
        TaskGoStraightToCoord(ped, coords, 1.2, -1, 0.0, 0.0)
        pedDist = #(coords - pedCoords)

        if PlayerDist > 10.0 then
            ClearSellingTarget(ped, 'error.too_far', 'error')
            return
        end
        Wait(100)
    end

    -- Position ped
    FreezeEntityPosition(ped, true)
    TaskLookAtEntity(ped, PlayerPedId(), 5500.0, 2048, 3)
    TaskTurnPedToFaceEntity(ped, PlayerPedId(), 5500)
    SetEntityHeading(ped, GetEntityHeading(PlayerPedId()) + 180)
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_IMPATIENT_UPRIGHT', 0, false)
    SellingData.Target = ped

    local rejectChance = (SellingData.Personality and tonumber(SellingData.Personality.RejectChance)) or 0.1
    if math.random() < rejectChance then
        ClearSellingTarget(ped, 'error.cust_refused', 'error')
        return
    end

    -- Selling loop
    while pedDist < OffsetData.Distance and SellingData.HasTarget do
        Wait(0) -- linter friendly wait
        local playerCoords = GetEntityCoords(PlayerPedId())
        coords = GetOffsetFromEntityInWorldCoords(StandObject, OffsetData.x, OffsetData.y, OffsetData.z)
        local PlayerDist = #(playerCoords - coords)
        pedCoords = GetEntityCoords(ped)
        pedDist = #(coords - pedCoords)

        if PlayerDist < 4 and HotdogsForSale > 0 and SellingPrice > 0 then
            if Config.UseTarget then
                if not zoneMade then
                    zoneMade = true
                    exports['qb-target']:AddEntityZone('sellingDogPed', ped, {
                        name = 'sellingDogPed',
                        debugPoly = false,
                    }, {
                        options = {
                            {
                                icon = 'fas fa-hand-holding-dollar',
                                label = Lang:t('info.sell_dogs_target', { value = HotdogsForSale, value2 = (HotdogsForSale * SellingPrice) }) .. ' - ' .. BuildOfferContextTargetText(),
                                action = function(entity)
                                    QBCore.Functions.Notify(Lang:t('success.sold_hotdogs', { value = HotdogsForSale, value2 = (HotdogsForSale * SellingPrice) }), 'success')
                                    TriggerServerEvent('qb-hotdogjob:server:Sell', pedCoords, HotdogsForSale, SellingPrice)
                                    SellingData.HasTarget = false
                                    LoadAnim('mp_common')
                                    TaskPlayAnim(PlayerPedId(), 'mp_common', 'givetake1_b', 8.0, 8.0, 1100, 48, 0.0, 0, 0, 0)
                                    FreezeEntityPosition(entity, false)
                                    SetPedKeepTask(entity, false)
                                    SetEntityAsNoLongerNeeded(entity)
                                    ClearPedTasksImmediately(entity)
                                    MarkPedRecently(entity)
                                    Config.Stock[SellingData.Hotdog].Current = Config.Stock[SellingData.Hotdog].Current - HotdogsForSale
                                    SellingData.Hotdog = nil
                                    exports['qb-target']:RemoveZone('sellingDogPed')
                                    zoneMade = false
                                end,
                            },
                            {
                                icon = 'fas fa-x',
                                label = 'Decline offer',
                                action = function(entity)
                                    QBCore.Functions.Notify(Lang:t('error.cust_refused'), 'error')
                                    SellingData.HasTarget = false
                                    FreezeEntityPosition(entity, false)
                                    SetPedKeepTask(entity, false)
                                    SetEntityAsNoLongerNeeded(entity)
                                    ClearPedTasksImmediately(entity)
                                    MarkPedRecently(entity)
                                    SellingData.Hotdog = nil
                                    exports['qb-target']:RemoveZone('sellingDogPed')
                                    zoneMade = false
                                end,
                            },
                        },
                        distance = 1.5,
                    })
                end
            else
                local sellText = Lang:t('info.sell_dogs', { value = HotdogsForSale, value2 = (HotdogsForSale * SellingPrice) }) .. '<br>' .. BuildOfferContextText()
                local sellTextStr = tostring(sellText)
                CurrentSellPrompt = sellTextStr
                if TextState ~= sellTextStr or not IsTextVisible then
                    if Config.TextDisplayType == '3d' then DrawText3D(pedCoords, sellText) end
                end

                if IsControlJustPressed(0, 161) or IsDisabledControlJustPressed(0, 161) then
                    HideTextPrompt()
                    CurrentSellPrompt = nil
                    QBCore.Functions.Notify(Lang:t('success.sold_hotdogs', { value = HotdogsForSale, value2 = (HotdogsForSale * SellingPrice) }), 'success')
                    TriggerServerEvent('qb-hotdogjob:server:Sell', pedCoords, HotdogsForSale, SellingPrice)
                    SellingData.HasTarget = false
                    local Myped = PlayerPedId()
                    LoadAnim('mp_common')
                    TaskPlayAnim(Myped, 'mp_common', 'givetake1_b', 8.0, 8.0, 1100, 48, 0.0, 0, 0, 0)
                    HotdogObject = CreateObject(`prop_cs_hotdog_01`, 0, 0, 0, true, true, true)
                    local hotdogOffset = AttachmentOffsets.Hotdog
                    AttachEntityToEntity(HotdogObject, Myped, GetPedBoneIndex(Myped, BoneIndices.Hand),
                        hotdogOffset.x, hotdogOffset.y, hotdogOffset.z,
                        hotdogOffset.rotX, hotdogOffset.rotY, hotdogOffset.rotZ,
                        true, true, false, true, 1, true)
                    SetTimeout(1250, function()
                        if HotdogObject then
                            DetachEntity(HotdogObject, 1, 1)
                            DeleteEntity(HotdogObject)
                            HotdogObject = nil
                        end
                    end)
                    FreezeEntityPosition(ped, false)
                    SetPedKeepTask(ped, false)
                    SetEntityAsNoLongerNeeded(ped)
                    ClearPedTasksImmediately(ped)
                    MarkPedRecently(ped)
                    Config.Stock[SellingData.Hotdog].Current = Config.Stock[SellingData.Hotdog].Current - HotdogsForSale
                    SellingData.Hotdog = nil
                    break
                end

                if IsControlJustPressed(0, 162) or IsDisabledControlJustPressed(0, 162) then
                    HideTextPrompt()
                    CurrentSellPrompt = nil
                    QBCore.Functions.Notify(Lang:t('error.cust_refused'), 'error')
                    SellingData.HasTarget = false
                    FreezeEntityPosition(ped, false)
                    SetPedKeepTask(ped, false)
                    SetEntityAsNoLongerNeeded(ped)
                    ClearPedTasksImmediately(ped)
                    MarkPedRecently(ped)
                    SellingData.Hotdog = nil
                    break
                end
            end
        else
            CurrentSellPrompt = nil
            SellingData.HasTarget = false
            FreezeEntityPosition(ped, false)
            SetPedKeepTask(ped, false)
            SetEntityAsNoLongerNeeded(ped)
            ClearPedTasksImmediately(ped)
            MarkPedRecently(ped)
            SellingData.Enabled, SellingData.Target, SellingData.HasTarget, SellingData.Hotdog = false, nil, false, nil
            if PlayerDist >= 4 then
                QBCore.Functions.Notify(Lang:t('error.too_far'), 'error')
            else
                -- Prevent notification spam with cooldown (5 seconds)
                local currentTime = GetGameTimer()
                if currentTime - LastNoDogsNotify > 5000 then
                    QBCore.Functions.Notify(Lang:t('error.no_dogs'), 'error')
                    LastNoDogsNotify = currentTime
                    -- Stop selling if no hotdogs available
                    SellingData.Enabled = false
                end
            end
            break
        end
    Wait(25)
    end
end

local function ToggleSell()
    if not StandObject or not DoesEntityExist(StandObject) then
        QBCore.Functions.Notify(Lang:t('error.no_stand'), 'error')
        return
    end

    local pos, objpos = GetEntityCoords(PlayerPedId()), GetEntityCoords(StandObject)
    if #(pos - objpos) > 5.0 then
        QBCore.Functions.Notify(Lang:t('error.too_far'), 'error')
        return
    end

    if not SellingData.Enabled then
        SellingData.Enabled = true

        -- Use PolyZone selling zone if available, otherwise fallback to manual checking
        if StandZones.SellingZone then
            StandZones.SellingZone:onPlayerInOut(function(isPointInside)
                InStandZones.Selling = isPointInside
            end)
        end

        CreateThread(function()
            while SellingData.Enabled and StandObject and DoesEntityExist(StandObject) do
                Wait(THREAD_SLOW_UPDATE_INTERVAL) -- Reduced from 0ms to improve performance

                -- Check if we have any hotdogs available before trying to sell
                local hasHotdogs = GetAvailableHotdog() ~= nil
                if not hasHotdogs then
                    -- Stop selling if no hotdogs available
                    SellingData.Enabled = false
                    local currentTime = GetGameTimer()
                    if currentTime - LastNoDogsNotify > 5000 then
                        QBCore.Functions.Notify(Lang:t('error.no_dogs'), 'error')
                        LastNoDogsNotify = currentTime
                    end
                    break
                end

                if not SellingData.HasTarget then
                    local coords = GetOffsetFromEntityInWorldCoords(StandObject, OffsetData.x, OffsetData.y, OffsetData.z)
                    local PlayerPeds = {}
                    for _, player in ipairs(GetActivePlayers()) do
                        PlayerPeds[#PlayerPeds + 1] = GetPlayerPed(player)
                    end
                    local closestPed, closestDistance = QBCore.Functions.GetClosestPed(coords, PlayerPeds)

                    -- Check if ped is in selling zone (if using PolyZone) or within distance
                    local inSellingArea = StandZones.SellingZone and InStandZones.Selling or (closestDistance < ZoneConfig.SellingZone.size)

                    if inSellingArea and closestPed ~= 0 and not IsPedInAnyVehicle(closestPed, false) then
                        SellToPed(closestPed)
                    end
                end
            end
        end)
    else
        CurrentSellPrompt = nil
        if SellingData.Target then
            SetPedKeepTask(SellingData.Target, false)
            SetEntityAsNoLongerNeeded(SellingData.Target)
            ClearPedTasksImmediately(SellingData.Target)
        end
        SellingData.Enabled, SellingData.Target, SellingData.HasTarget = false, nil, false
        SellingData.Personality, SellingData.DemandMultiplier, SellingData.DemandLabel = nil, 1.0, 'default'
    end
end

-- Events
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    UpdateBlip()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerData = PlayerData or {}
    PlayerData.job = JobInfo
    UpdateBlip()
end)

RegisterNetEvent('qb-hotdogjob:client:UpdateReputation', function(JobRep)
    PlayerData = PlayerData or {}
    PlayerData.metadata = PlayerData.metadata or {}
    PlayerData.metadata['rep'] = JobRep
    UpdateLevel()
end)

RegisterNetEvent('qb-hotdogjob:client:ToggleSell', ToggleSell)

RegisterNetEvent('qb-hotdogjob:staff:DeletStand', function()
    local pos = GetEntityCoords(PlayerPedId())
    local Object = GetClosestObjectOfType(pos.x, pos.y, pos.z, 10.0, `prop_hotdogstand_01`, true, false, false)
    if Object and #(pos - GetEntityCoords(Object)) <= 5 then
        NetworkRegisterEntityAsNetworked(Object)
        Wait(100)
        NetworkRequestControlOfEntity(Object)
        if not IsEntityAMissionEntity(Object) then SetEntityAsMissionEntity(Object) end
        Wait(100)
        DeleteEntity(Object)
        QBCore.Functions.Notify(Lang:t('info.admin_removed'), 'primary')
    end
end)

-- Key Mapping
if Config.UseTarget then
    RegisterCommand('letgostand', function()
        if IsPushing then LetKraamLose() end
    end)
    RegisterKeyMapping('letgostand', Lang:t('keymapping.gkey'), 'keyboard', 'G')
end

-- Initialization
CreateThread(function()
    if Config.UseTarget then
        exports['qb-target']:AddBoxZone('hotdog_start', vector3(Config.Locations['take'].coords.x, Config.Locations['take'].coords.y, Config.Locations['take'].coords.z), 1, 1, {
            name = 'hotdog_start',
            debugPoly = false,
            heading = Config.Locations['take'].coords.w,
            minZ = Config.Locations['take'].coords.z - 1,
            maxZ = Config.Locations['take'].coords.z + 1,
        }, {
            options = {
                {
                    label = 'Toggle Work',
                    job = Config.RequireJob and Config.JobName or nil,
                    icon = 'fa-solid fa-hotdog',
                    action = function()
                        if not IsWorking then StartWorking() else StopWorking() end
                    end
                }
            },
            distance = 2.5
        })
    else
        local inZone = false
        local hotdogStart = BoxZone:Create(vector3(Config.Locations['take'].coords.x, Config.Locations['take'].coords.y, Config.Locations['take'].coords.z), 1.0, 1.0, {
            name = 'hotdog_start',
            debugPoly = false,
            minZ = Config.Locations['take'].coords.z - 1,
            maxZ = Config.Locations['take'].coords.z + 1,
        })

        hotdogStart:onPlayerInOut(function(isPointInside)
            if isPointInside then
                inZone = true
                PlayerData = QBCore.Functions.GetPlayerData()
                if HasRequiredJob() then
                    local text = IsWorking and Lang:t('info.stop_working') or Lang:t('info.start_working')
                    exports['qb-core']:DrawText(StripColorCodes(text), 'left')
                    CreateThread(function()
                        while inZone do
                            Wait(0)
                            if IsControlJustPressed(0, 38) then
                                if not IsWorking then StartWorking() else StopWorking() end
                            end
                        end
                    end)
                end
            else
                inZone = false
                exports['qb-core']:HideText()
            end
        end)
    end
end)