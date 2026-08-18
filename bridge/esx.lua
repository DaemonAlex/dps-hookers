--[[
    dps-hookers - ESX Bridge
    Wraps ESX functions in standard Bridge.* calls
]]

local ESX = exports['es_extended']:getSharedObject()

if IsDuplicityVersion() then
    -----------------------------------------------------------
    -- SERVER SIDE
    -----------------------------------------------------------

    ---@param source number Player server ID
    ---@return table|nil Player object
    function Bridge.GetPlayer(source)
        return ESX.GetPlayerFromId(source)
    end

    ---@param source number Player server ID
    ---@return string Full character name
    function Bridge.GetCharacterName(source)
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return 'Unknown' end
        return xPlayer.getName()
    end

    ---@param source number Player server ID
    ---@return string|nil Birthdate string or nil
    function Bridge.GetBirthdate(source)
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return nil end
        -- ESX stores birthdate in identity table - check for esx_identity
        local identity = xPlayer.get('identity')
        if identity and identity.dateofbirth then
            return identity.dateofbirth
        end
        -- Fallback: Return a default adult birthdate if no identity system
        return '1990-01-01'
    end

    ---@param source number Player server ID
    ---@return string, number Job name and grade
    function Bridge.GetJob(source)
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return 'unemployed', 0 end
        return xPlayer.job.name, xPlayer.job.grade
    end

    ---@param source number Player server ID
    ---@return string Player identifier
    function Bridge.GetIdentifier(source)
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return nil end
        return xPlayer.identifier
    end

    ---@param source number Player server ID
    ---@param account string 'cash' or 'bank'
    ---@param amount number Amount to remove
    ---@param reason string Transaction reason
    ---@return boolean Success
    function Bridge.RemoveMoney(source, account, amount, reason)
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return false end

        -- ESX uses 'money' for cash
        if account == 'cash' then account = 'money' end

        local accountData = xPlayer.getAccount(account)
        if accountData and accountData.money >= amount then
            xPlayer.removeAccountMoney(account, amount, reason or 'dps-hookers')
            return true
        end
        return false
    end

    ---@param source number Player server ID
    ---@param account string 'cash' or 'bank'
    ---@param amount number Amount to add
    ---@param reason string Transaction reason
    ---@return boolean Success
    function Bridge.AddMoney(source, account, amount, reason)
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return false end

        -- ESX uses 'money' for cash
        if account == 'cash' then account = 'money' end

        xPlayer.addAccountMoney(account, amount, reason or 'dps-hookers')
        return true
    end

    ---@param source number Player server ID
    ---@param account string 'cash' or 'bank'
    ---@return number Balance
    function Bridge.GetMoney(source, account)
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return 0 end

        -- ESX uses 'money' for cash
        if account == 'cash' then account = 'money' end

        local accountData = xPlayer.getAccount(account)
        return accountData and accountData.money or 0
    end

    ---@return table Array of player server IDs
    function Bridge.GetPlayers()
        local xPlayers = ESX.GetExtendedPlayers()
        local playerIds = {}
        for _, xPlayer in pairs(xPlayers) do
            table.insert(playerIds, xPlayer.source)
        end
        return playerIds
    end

    ---@param source number Player server ID
    ---@param title string Notification title (ignored in ESX)
    ---@param msg string Notification message
    ---@param type string 'success', 'error', 'inform'
    function Bridge.Notify(source, title, msg, type)
        TriggerClientEvent('esx:showNotification', source, msg)
    end

    ---@param cb function Callback when player loads
    function Bridge.OnPlayerLoaded(cb)
        RegisterNetEvent('esx:playerLoaded', function(playerId, xPlayer)
            cb(playerId)
        end)
    end

    ---@param cb function Callback when player unloads
    function Bridge.OnPlayerUnload(cb)
        AddEventHandler('esx:playerDropped', function(playerId)
            cb(playerId)
        end)
    end

else
    -----------------------------------------------------------
    -- CLIENT SIDE
    -----------------------------------------------------------

    ---@return table Player data
    function Bridge.GetPlayerData()
        return ESX.GetPlayerData()
    end

    ---@return string, number Job name and grade
    function Bridge.GetJob()
        local PlayerData = ESX.GetPlayerData()
        if not PlayerData or not PlayerData.job then return 'unemployed', 0 end
        return PlayerData.job.name, PlayerData.job.grade
    end

    ---@return boolean Is player loaded
    function Bridge.IsPlayerLoaded()
        local PlayerData = ESX.GetPlayerData()
        return PlayerData and PlayerData.identifier ~= nil
    end

    ---@param cb function Callback when player loads
    function Bridge.OnPlayerLoaded(cb)
        RegisterNetEvent('esx:playerLoaded', function(xPlayer)
            cb()
        end)
    end

    ---@param cb function Callback when player unloads
    function Bridge.OnPlayerUnload(cb)
        RegisterNetEvent('esx:onPlayerLogout', function()
            cb()
        end)
    end

    ---@param cb function Callback when job updates
    function Bridge.OnJobUpdate(cb)
        RegisterNetEvent('esx:setJob', function(job)
            cb(job)
        end)
    end

    ---@param msg string Notification message
    ---@param type string 'success', 'error', 'inform' (ignored in ESX)
    function Bridge.Notify(msg, type)
        ESX.ShowNotification(msg)
    end
end
