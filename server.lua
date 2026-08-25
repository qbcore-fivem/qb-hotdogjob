local QBCore = exports['qb-core']:GetCoreObject({ 'Functions', 'Commands' })
local Bail = {}

-- Callbacks

QBCore.Functions.CreateCallback('qb-hotdogjob:server:HasMoney', function(source, cb)
    local Player = exports['qb-core']:GetPlayer(source)

    if Player.PlayerData.money.bank >= Config.StandDeposit then
        Player.RemoveMoney('bank', Config.StandDeposit, 'hot dog deposit')
        Bail[Player.PlayerData.citizenid] = true
        cb(true)
    else
        Bail[Player.PlayerData.citizenid] = false
        cb(false)
    end
end)

QBCore.Functions.CreateCallback('qb-hotdogjob:server:BringBack', function(source, cb)
    local Player = exports['qb-core']:GetPlayer(source)

    if Bail[Player.PlayerData.citizenid] then
        Player.AddMoney('bank', Config.StandDeposit, 'hot dog deposit')
        cb(true)
    else
        cb(false)
    end
end)

-- Events

RegisterNetEvent('qb-hotdogjob:server:Sell', function(coords, hotdogType, amount, price)
    local src = source
    local pCoords = GetEntityCoords(GetPlayerPed(src))
    local Player = exports['qb-core']:GetPlayer(src)
    if not Player then return end

    -- Distance exploit check
    if #(pCoords - coords) > 4 then
        exports['qb-core']:ExploitBan(src, 'hotdog job')
        return
    end

    -- Validate hotdog type exists in config
    local stockCfg = Config.Stock[hotdogType]
    if not stockCfg then return end

    -- Validate amount is a positive integer
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return end

    -- Validate price is within the configured range for any level
    price = tonumber(price)
    if not price then return end
    local priceValid = false
    for _, levelPrice in pairs(stockCfg.Price) do
        if price >= levelPrice.min and price <= levelPrice.max then
            priceValid = true
            break
        end
    end
    if not priceValid then
        exports['qb-core']:ExploitBan(src, 'hotdog job - invalid price')
        return
    end

    -- Server-side inventory check: clamp amount to what the player actually owns
    local itemName = 'hotdog_' .. hotdogType
    local item = Player.Functions.GetItemByName(itemName)
    if not item or item.amount <= 0 then return end
    amount = math.min(amount, item.amount)

    -- Remove item first, then pay
    if Player.Functions.RemoveItem(itemName, amount) then
        Player.Functions.AddMoney('cash', amount * price, 'sold hotdog')
    end
end)

RegisterNetEvent('qb-hotdogjob:server:UpdateReputation', function(quality)
    local src = source
    local Player = exports['qb-core']:GetPlayer(src)
    if quality == 'exotic' then
        if Player.GetRep('hotdog') + 3 > Config.MaxReputation then
            Player.AddRep('hotdog', Config.MaxReputation - Player.GetRep('hotdog'))
        else
            Player.AddRep('hotdog', 3)
        end
    elseif quality == 'rare' then
        if Player.GetRep('hotdog') + 2 > Config.MaxReputation then
            Player.AddRep('hotdog', Config.MaxReputation - Player.GetRep('hotdog'))
        else
            Player.AddRep('hotdog', 2)
        end
    elseif quality == 'common' then
        if Player.GetRep('hotdog') + 1 > Config.MaxReputation then
            Player.AddRep('hotdog', Config.MaxReputation - Player.GetRep('hotdog'))
        else
            Player.AddRep('hotdog', 1)
        end
    end

    TriggerClientEvent('qb-hotdogjob:client:UpdateReputation', src, Player.PlayerData.metadata['rep'])
end)

-- Commands

QBCore.Commands.Add('removestand', Lang:t('info.command'), {}, false, function(source, _)
    TriggerClientEvent('qb-hotdogjob:staff:DeletStand', source)
end, 'admin')
