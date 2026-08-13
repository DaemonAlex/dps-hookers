--[[
    dps-hookers - Qbox (qbx_core) Bridge
    Wraps qbx_core functions in standard Bridge.* calls.

    IMPORTANT: qbx_core has NO GetCoreObject() export (unlike legacy qb-core).
    All access is via discrete exports. PlayerData is qb-shaped, so field
    access (charinfo/citizenid/job) ports 1:1 from bridge/qb.lua.
]]

--- Fetch a player object from qbx_core (server-side)
---@param src number Player server ID
---@return table|nil
local function P(src)
    return exports.qbx_core:GetPlayer(src)
end

if IsDuplicityVersion() then
    -----------------------------------------------------------
    -- SERVER SIDE
    -----------------------------------------------------------

    ---@param source number Player server ID
    ---@return table|nil Player object
    function Bridge.GetPlayer(source)
        return exports.qbx_core:GetPlayer(source)
    end

    ---@param source number Player server ID
    ---@return string Full character name
    function Bridge.GetCharacterName(source)
        local player = P(source)
        if not player then return 'Unknown' end
        local charinfo = player.PlayerData.charinfo
        return charinfo.firstname .. ' ' .. charinfo.lastname
    end

    ---@param source number Player server ID
    ---@return string|nil Birthdate string or nil
    function Bridge.GetBirthdate(source)
        local player = P(source)
        if not player then return nil end
        local charinfo = player.PlayerData.charinfo
        return charinfo and charinfo.birthdate or nil
    end

    ---@param source number Player server ID
    ---@return string, number Job name and grade
    function Bridge.GetJob(source)
        local player = P(source)
        if not player then return 'unemployed', 0 end
        return player.PlayerData.job.name, player.PlayerData.job.grade.level
    end

    ---@param source number Player server ID
    ---@return string|nil Player identifier (citizenid)
    function Bridge.GetIdentifier(source)
        local player = P(source)
        if not player then return nil end
        return player.PlayerData.citizenid
    end

    ---@param source number Player server ID
    ---@param account string 'cash' or 'bank'
    ---@param amount number Amount to remove
    ---@param reason string Transaction reason
    ---@return boolean Success
    function Bridge.RemoveMoney(source, account, amount, reason)
        local player = P(source)
        if not player then return false end
        return player.Functions.RemoveMoney(account, amount, reason or 'dps-hookers')
    end

    ---@param source number Player server ID
    ---@param account string 'cash' or 'bank'
    ---@param amount number Amount to add
    ---@param reason string Transaction reason
    ---@return boolean Success
    function Bridge.AddMoney(source, account, amount, reason)
        local player = P(source)
        if not player then return false end
        return player.Functions.AddMoney(account, amount, reason or 'dps-hookers')
    end

    ---@param source number Player server ID
    ---@param account string 'cash' or 'bank'
    ---@return number Balance
    function Bridge.GetMoney(source, account)
        local player = P(source)
        if not player then return 0 end
        return player.Functions.GetMoney(account)
    end

    ---@return table Map/array of active players (keyed by source in qbx)
    function Bridge.GetPlayers()
        return exports.qbx_core:GetQBPlayers()
    end

    ---@param source number Player server ID
    ---@param title string Notification title
    ---@param msg string Notification message
    ---@param type string 'success', 'error', 'inform'
    function Bridge.Notify(source, title, msg, type)
        lib.notify(source, {
            title = title,
            description = msg,
            type = type or 'inform'
        })
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
        return exports.qbx_core:GetPlayerData()
    end

    ---@return string, number Job name and grade
    function Bridge.GetJob()
        local PlayerData = exports.qbx_core:GetPlayerData()
        if not PlayerData or not PlayerData.job then return 'unemployed', 0 end
        return PlayerData.job.name, PlayerData.job.grade.level
    end

    ---@return boolean Is player loaded
    function Bridge.IsPlayerLoaded()
        local PlayerData = exports.qbx_core:GetPlayerData()
        return PlayerData ~= nil and PlayerData.citizenid ~= nil
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
        lib.notify({
            description = msg,
            type = type or 'inform'
        })
    end
end
