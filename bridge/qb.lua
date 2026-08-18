--[[
    dps-hookers - QBCore Bridge
    Wraps QBCore functions in standard Bridge.* calls
]]

local QBCore = exports['qb-core']:GetCoreObject()

if IsDuplicityVersion() then
    -----------------------------------------------------------
    -- SERVER SIDE
    -----------------------------------------------------------

    ---@param source number Player server ID
    ---@return table|nil Player object
    function Bridge.GetPlayer(source)
        return QBCore.Functions.GetPlayer(source)
    end

    ---@param source number Player server ID
    ---@return string Full character name
    function Bridge.GetCharacterName(source)
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return 'Unknown' end
        local charinfo = Player.PlayerData.charinfo
        return charinfo.firstname .. ' ' .. charinfo.lastname
    end

    ---@param source number Player server ID
    ---@return string|nil Birthdate string or nil
    function Bridge.GetBirthdate(source)
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return nil end
        local charinfo = Player.PlayerData.charinfo
        return charinfo and charinfo.birthdate or nil
    end

    ---@param source number Player server ID
    ---@return string, number Job name and grade
    function Bridge.GetJob(source)
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return 'unemployed', 0 end
        return Player.PlayerData.job.name, Player.PlayerData.job.grade.level
    end

    ---@param source number Player server ID
    ---@return string Player identifier (citizenid)
    function Bridge.GetIdentifier(source)
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return nil end
        return Player.PlayerData.citizenid
    end

    ---@param source number Player server ID
    ---@param account string 'cash' or 'bank'
    ---@param amount number Amount to remove
    ---@param reason string Transaction reason
    ---@return boolean Success
    function Bridge.RemoveMoney(source, account, amount, reason)
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return false end
        return Player.Functions.RemoveMoney(account, amount, reason or 'dps-hookers')
    end

    ---@param source number Player server ID
    ---@param account string 'cash' or 'bank'
    ---@param amount number Amount to add
    ---@param reason string Transaction reason
    ---@return boolean Success
    function Bridge.AddMoney(source, account, amount, reason)
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return false end
        return Player.Functions.AddMoney(account, amount, reason or 'dps-hookers')
    end

    ---@param source number Player server ID
    ---@param account string 'cash' or 'bank'
    ---@return number Balance
    function Bridge.GetMoney(source, account)
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return 0 end
        return Player.Functions.GetMoney(account)
    end

    ---@return table Array of player server IDs
    function Bridge.GetPlayers()
        return QBCore.Functions.GetPlayers()
    end

    ---@param source number Player server ID
    ---@param title string Notification title
    ---@param msg string Notification message
    ---@param type string 'success', 'error', 'inform'
    function Bridge.Notify(source, title, msg, type)
        TriggerClientEvent('QBCore:Notify', source, msg, type)
    end

    ---@param cb function Callback when player loads
    function Bridge.OnPlayerLoaded(cb)
        RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
            cb(source)
        end)
    end

    ---@param cb function Callback when player unloads
    function Bridge.OnPlayerUnload(cb)
        RegisterNetEvent('QBCore:Server:OnPlayerUnload', function()
            cb(source)
        end)
    end

else
    -----------------------------------------------------------
    -- CLIENT SIDE
    -----------------------------------------------------------

    ---@return table Player data
    function Bridge.GetPlayerData()
        return QBCore.Functions.GetPlayerData()
    end

    ---@return string, number Job name and grade
    function Bridge.GetJob()
        local PlayerData = QBCore.Functions.GetPlayerData()
        if not PlayerData or not PlayerData.job then return 'unemployed', 0 end
        return PlayerData.job.name, PlayerData.job.grade.level
    end

    ---@return boolean Is player loaded
    function Bridge.IsPlayerLoaded()
        local PlayerData = QBCore.Functions.GetPlayerData()
        return PlayerData and PlayerData.citizenid ~= nil
    end

    ---@param cb function Callback when player loads
    function Bridge.OnPlayerLoaded(cb)
        RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
            cb()
        end)
    end

    ---@param cb function Callback when player unloads
    function Bridge.OnPlayerUnload(cb)
        RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
            cb()
        end)
    end

    ---@param cb function Callback when job updates
    function Bridge.OnJobUpdate(cb)
        RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
            cb(job)
        end)
    end

    ---@param msg string Notification message
    ---@param type string 'success', 'error', 'inform'
    function Bridge.Notify(msg, type)
        QBCore.Functions.Notify(msg, type)
    end
end
