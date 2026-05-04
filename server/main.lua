local QBCore = exports['qb-core']:GetCoreObject()
local Bail = {}

local MAX_SELL_AMOUNT = 3
local MIN_SELL_PRICE = 1
local MAX_SELL_PRICE = 100
local ENABLE_SELL_REJECT_LOGGING = true

local function LogRejectedSell(src, reason, details)
    if not ENABLE_SELL_REJECT_LOGGING then return end
    local suffix = details and (' | ' .. details) or ''
    print(('[qb-hotdogjob] Rejected sell from %s: %s%s'):format(src, reason, suffix))
end

-- Callbacks

QBCore.Functions.CreateCallback('qb-hotdogjob:server:HasMoney', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb(false)
        return
    end

    if Player.PlayerData.money.bank >= Config.StandDeposit then
        Player.Functions.RemoveMoney('bank', Config.StandDeposit, 'hot dog deposit')
        Bail[Player.PlayerData.citizenid] = true
        cb(true)
    else
        Bail[Player.PlayerData.citizenid] = false
        cb(false)
    end
end)

QBCore.Functions.CreateCallback('qb-hotdogjob:server:BringBack', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb(false)
        return
    end

    if Bail[Player.PlayerData.citizenid] then
        Player.Functions.AddMoney('bank', Config.StandDeposit, 'hot dog deposit')
        Bail[Player.PlayerData.citizenid] = nil -- Clean up the Bail entry
        cb(true)
    else
        cb(false)
    end
end)

-- Events

RegisterNetEvent('qb-hotdogjob:server:Sell', function(coords, amount, price)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        LogRejectedSell(src, 'player_not_found')
        return
    end

    local ped = GetPlayerPed(src)
    if ped <= 0 then
        LogRejectedSell(src, 'invalid_ped')
        return
    end

    if type(coords) ~= 'vector3' then
        LogRejectedSell(src, 'invalid_coords_type', ('type=%s'):format(type(coords)))
        return
    end

    local sellAmount = tonumber(amount)
    local sellPrice = tonumber(price)
    if not sellAmount or not sellPrice then
        LogRejectedSell(src, 'invalid_amount_or_price', ('amount=%s price=%s'):format(tostring(amount), tostring(price)))
        return
    end

    sellAmount = math.floor(sellAmount)
    sellPrice = math.floor(sellPrice)

    if sellAmount < 1 or sellAmount > MAX_SELL_AMOUNT then
        LogRejectedSell(src, 'amount_out_of_range', ('amount=%s'):format(sellAmount))
        return
    end
    if sellPrice < MIN_SELL_PRICE or sellPrice > MAX_SELL_PRICE then
        LogRejectedSell(src, 'price_out_of_range', ('price=%s'):format(sellPrice))
        return
    end

    local pCoords = GetEntityCoords(ped)
    if #(pCoords - coords) > 4.0 then
        LogRejectedSell(src, 'distance_check_failed')
        exports['qb-core']:ExploitBan(src, 'hotdog job')
        return
    end

    local payout = sellAmount * sellPrice
    if payout <= 0 then
        LogRejectedSell(src, 'invalid_payout', ('payout=%s'):format(payout))
        return
    end
    Player.Functions.AddMoney('cash', payout, 'sold hotdog')
end)

RegisterNetEvent('qb-hotdogjob:server:UpdateReputation', function(quality)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if quality == 'exotic' then
        if Player.Functions.GetRep('hotdog') + 3 > Config.MaxReputation then
            Player.Functions.AddRep('hotdog', Config.MaxReputation - Player.Functions.GetRep('hotdog'))
        else
            Player.Functions.AddRep('hotdog', 3)
        end
    elseif quality == 'rare' then
        if Player.Functions.GetRep('hotdog') + 2 > Config.MaxReputation then
            Player.Functions.AddRep('hotdog', Config.MaxReputation - Player.Functions.GetRep('hotdog'))
        else
            Player.Functions.AddRep('hotdog', 2)
        end
    elseif quality == 'common' then
        if Player.Functions.GetRep('hotdog') + 1 > Config.MaxReputation then
            Player.Functions.AddRep('hotdog', Config.MaxReputation - Player.Functions.GetRep('hotdog'))
        else
            Player.Functions.AddRep('hotdog', 1)
        end
    end

    TriggerClientEvent('qb-hotdogjob:client:UpdateReputation', src, Player.PlayerData.metadata['rep'])
end)

-- Commands

QBCore.Commands.Add('removestand', Lang:t('info.command'), {}, false, function(source, _)
    TriggerClientEvent('qb-hotdogjob:staff:DeletStand', source)
end, 'admin')
