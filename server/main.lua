--[[ ===================================================== ]]--
--[[       DPS Hookers - Server Controller                ]]--
--[[       Handles payments, age verification, police     ]]--
--[[ ===================================================== ]]--

-- Police alert cooldown tracking (per player)
local policeAlertCooldowns = {}

-- Active service tracking (prevent double-charge exploits)
local activeServices = {}

--[[ ===================================================== ]]--
--[[                  UTILITY FUNCTIONS                    ]]--
--[[ ===================================================== ]]--

--- Get QB-Core object
local QBCore = exports['qb-core']:GetCoreObject()

--- Get QB-Core player object
---@param src number Player source ID
---@return table|nil Player object or nil
local function getPlayer(src)
    return QBCore.Functions.GetPlayer(src)
end

--- Send notification to player
---@param src number Player source ID
---@param message string Notification message
---@param type string Notification type (success, error, info)
local function notify(src, message, type)
    lib.notify(src, {
        title = 'DPS Hookers',
        description = message,
        type = type or 'info'
    })
end

--- Check if player is underage (under 18)
---@param src number Player source ID
---@return boolean True if player is under 18
local function isPlayerUnderage(src)
    local player = getPlayer(src)
    if not player then return true end

    local charinfo = player.PlayerData.charinfo
    if not charinfo or not charinfo.birthdate then return true end

    local birthdate = charinfo.birthdate

    -- Parse birthdate (format: YYYY-MM-DD or DD/MM/YYYY)
    local birthdateParts = {}

    -- Handle different date formats
    if string.match(birthdate, "%d+/%d+/%d+") then
        -- DD/MM/YYYY format
        for value in string.gmatch(birthdate, "[^/]+") do
            table.insert(birthdateParts, tonumber(value))
        end
        -- Reorder to YYYY, MM, DD
        local day = birthdateParts[1]
        local month = birthdateParts[2]
        local year = birthdateParts[3]
        birthdateParts = {year, month, day}
    else
        -- YYYY-MM-DD format
        for value in string.gmatch(birthdate, "[^-]+") do
            table.insert(birthdateParts, tonumber(value))
        end
    end

    if #birthdateParts < 3 then return true end

    -- Parse current date
    local currentDate = {}
    for value in string.gmatch(os.date("%Y-%m-%d"), "[^-]+") do
        table.insert(currentDate, tonumber(value))
    end

    -- Calculate age (QB uses -4 year offset for RP time)
    local age = currentDate[1] - birthdateParts[1] - 4

    -- Adjust for month/day
    if currentDate[2] < birthdateParts[2] or
       (currentDate[2] == birthdateParts[2] and currentDate[3] < birthdateParts[3]) then
        age = age - 1
    end

    return age < 18
end

--- Remove player stress (configurable target)
---@param src number Player source ID
---@param amount number Amount of stress to remove
local function removeStress(src, amount)
    -- Try multiple stress systems
    if Config.StressSystem == 'qb-hud' then
        TriggerClientEvent('hud:client:RelieveStress', src, amount)
    elseif Config.StressSystem == 'qbx-hud' then
        TriggerClientEvent('hud:client:RelieveStress', src, amount)
    elseif Config.StressSystem == 'custom' then
        -- Custom stress event - configure in config.lua
        if Config.CustomStressEvent then
            TriggerClientEvent(Config.CustomStressEvent, src, amount)
        end
    else
        -- Default: try common stress event
        TriggerClientEvent('hud:client:RelieveStress', src, amount)
    end
end

--- Check if player is on police alert cooldown
---@param src number Player source ID
---@return boolean True if on cooldown
local function isOnPoliceCooldown(src)
    if not policeAlertCooldowns[src] then return false end

    local timeSince = os.time() - policeAlertCooldowns[src]
    return timeSince < Config.Police.Cooldown
end

--- Set police alert cooldown for player
---@param src number Player source ID
local function setPoliceCooldown(src)
    policeAlertCooldowns[src] = os.time()
end

--- Check if player is currently in a service
---@param src number Player source ID
---@return boolean
local function isInService(src)
    return activeServices[src] ~= nil
end

--- Set player service state
---@param src number Player source ID
---@param serviceType string|nil Service type or nil to clear
local function setServiceState(src, serviceType)
    if serviceType then
        activeServices[src] = {
            type = serviceType,
            startTime = os.time()
        }
    else
        activeServices[src] = nil
    end
end

--[[ ===================================================== ]]--
--[[                   SERVER EVENTS                       ]]--
--[[ ===================================================== ]]--

--- Handle player joining/loading the resource
RegisterServerEvent('dps-hookers:server:onJoin', function()
    local src = source
    local player = getPlayer(src)

    if not player then return end

    -- Check age verification
    if Config.AgeVerification then
        if isPlayerUnderage(src) then
            print(("[DPS Hookers] Player %s (%s) is underage - access denied"):format(
                GetPlayerName(src),
                src
            ))
            TriggerClientEvent('dps-hookers:client:ageRestricted', src)
            return
        end
    end

    -- Send config to client
    TriggerClientEvent('dps-hookers:client:onJoin', src, {
        status = true
    })
end)

--- Handle payment for services
RegisterServerEvent('dps-hookers:server:pay', function(data)
    local src = source
    local player = getPlayer(src)

    if not player then return end

    -- Security: Prevent double-charge exploits
    if isInService(src) then
        notify(src, 'You are already receiving a service.', 'error')
        return
    end

    local serviceType = data.type
    local cost = 0
    local serviceName = ''
    local animKey = ''

    -- Determine cost and service name
    if serviceType == 'blowjob' then
        cost = Config.Prices.Blowjob
        serviceName = 'blowjob'
        animKey = 'BlowjobDuration'
    elseif serviceType == 'havesex' then
        cost = Config.Prices.Sex
        serviceName = 'sex'
        animKey = 'SexDuration'
    else
        -- Invalid service type - potential exploit attempt
        print(("[DPS Hookers] Invalid service type from %s: %s"):format(GetPlayerName(src), tostring(serviceType)))
        return
    end

    -- Security: Server-side cash check
    local playerMoney = player.PlayerData.money
    local cash = playerMoney and playerMoney.cash or 0

    if cash < cost then
        notify(src, lib.locale('notifications.no_cash'), 'error')
        return
    end

    -- Remove money (server-side validation)
    local success = player.Functions.RemoveMoney('cash', cost, 'dps-hookers-service')

    if not success then
        notify(src, lib.locale('notifications.no_cash'), 'error')
        return
    end

    -- Set service state to prevent double-charge
    setServiceState(src, serviceType)

    -- Notify player of payment
    notify(src, lib.locale('notifications.paid', {
        cost = cost,
        type = serviceName
    }), 'success')

    -- Trigger client-side action (animations, etc.)
    TriggerClientEvent('dps-hookers:client:action', src, {
        status = true,
        type = serviceType
    })

    -- Get service duration
    local duration = Config.Animations[animKey] or 30000

    -- Reduce stress and clear service state after service completes
    local stressAmount = math.random(Config.StressRelief.Min, Config.StressRelief.Max)

    SetTimeout(duration, function()
        removeStress(src, stressAmount)
        notify(src, lib.locale('notifications.service_complete'), 'success')
        setServiceState(src, nil)  -- Clear service state
    end)
end)

--- Handle police dispatch roll
RegisterServerEvent('dps-hookers:server:policeRoll', function(coords, witnessCount)
    local src = source

    if not Config.Police.Enabled then return end
    if isOnPoliceCooldown(src) then return end

    -- Validate coords
    if not coords or type(coords) ~= 'vector3' then
        -- Try to convert table to vector3
        if type(coords) == 'table' and coords.x and coords.y and coords.z then
            coords = vector3(coords.x, coords.y, coords.z)
        else
            return
        end
    end

    -- Witness check: If enabled, require at least 1 witness NPC
    witnessCount = witnessCount or 0
    if Config.Police.RequireWitness and witnessCount < 1 then
        if Config.Debug then
            print(("[DPS Hookers] No witnesses for %s - no dispatch"):format(GetPlayerName(src)))
        end
        return
    end

    -- Calculate police risk chance
    local riskChance, reasons = Config.CalculatePoliceRisk(coords)

    -- Bonus risk for multiple witnesses
    if witnessCount > 1 then
        local witnessBonus = math.min(witnessCount * 5, 25)  -- +5% per witness, max +25%
        riskChance = riskChance + witnessBonus
        reasons.witnesses = witnessCount
        reasons.witnessBonus = witnessBonus
    end

    -- Roll the dice
    local roll = math.random(1, 100)

    -- Debug logging
    if Config.Debug then
        print(("[DPS Hookers] Police roll for %s: %d/%d (Risk: %d%%)"):format(
            GetPlayerName(src),
            roll,
            100,
            riskChance
        ))
    end

    if roll <= riskChance then
        -- Police were called!
        setPoliceCooldown(src)

        -- Get street name
        local streetHash, _ = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
        local streetName = GetStreetNameFromHashKey(streetHash) or 'Unknown Location'

        -- Calculate dispatch delay based on location
        local dispatchDelay = 0
        if Config.Police.DelayedDispatch and Config.Police.DelayedDispatch.enabled then
            local isSecluded = reasons.location == 'Secluded area' or reasons.location == 'Industrial zone'

            if isSecluded then
                local delayConfig = Config.Police.DelayedDispatch.secludedDelay
                dispatchDelay = math.random(delayConfig.min, delayConfig.max)
            else
                local delayConfig = Config.Police.DelayedDispatch.normalDelay
                dispatchDelay = math.random(delayConfig.min, delayConfig.max)
            end

            if Config.Debug then
                print(("[DPS Hookers] Dispatch delayed by %dms for %s"):format(dispatchDelay, GetPlayerName(src)))
            end
        end

        -- Function to actually send the dispatch
        local function sendDispatch()
            local dispatchSuccess = false

            if Config.Police.DispatchType == 'ps-dispatch' then
                local ok, err = pcall(function()
                    exports['ps-dispatch']:SuspiciousActivity({
                        message = lib.locale('police.dispatch_message'),
                        coords = coords,
                        street = streetName,
                        description = lib.locale('police.dispatch_street', {street = streetName}),
                        radius = Config.Police.BlipRadius,
                        sprite = 480,
                        color = 1,
                        scale = 1.0,
                        length = Config.Police.BlipDuration
                    })
                end)
                dispatchSuccess = ok
                if not ok and Config.Debug then
                    print(("[DPS Hookers] ps-dispatch error: %s"):format(tostring(err)))
                end

            elseif Config.Police.DispatchType == 'cd_dispatch' then
                local ok, err = pcall(function()
                    TriggerEvent('cd_dispatch:AddNotification', {
                        job_table = {'police'},
                        coords = coords,
                        title = lib.locale('police.dispatch_code') .. ' - ' .. lib.locale('police.dispatch_title'),
                        message = lib.locale('police.dispatch_street', {street = streetName}),
                        flash = 0,
                        unique_id = tostring(math.random(0000000, 9999999)),
                        blip = {
                            sprite = 480,
                            scale = 1.0,
                            colour = 1,
                            flashes = false,
                            text = lib.locale('police.dispatch_code'),
                            time = (Config.Police.BlipDuration * 1000),
                            sound = 1,
                        }
                    })
                end)
                dispatchSuccess = ok
                if not ok and Config.Debug then
                    print(("[DPS Hookers] cd_dispatch error: %s"):format(tostring(err)))
                end

            elseif Config.Police.DispatchType == 'qs-dispatch' then
                local ok, err = pcall(function()
                    exports['qs-dispatch']:SuspiciousActivity(coords, lib.locale('police.dispatch_message'))
                end)
                dispatchSuccess = ok
                if not ok and Config.Debug then
                    print(("[DPS Hookers] qs-dispatch error: %s"):format(tostring(err)))
                end

            elseif Config.Police.DispatchType == 'custom' then
                local ok, err = pcall(function()
                    TriggerEvent('police:dispatch', {
                        code = lib.locale('police.dispatch_code'),
                        title = lib.locale('police.dispatch_title'),
                        message = lib.locale('police.dispatch_message'),
                        coords = coords,
                        street = streetName,
                        radius = Config.Police.BlipRadius,
                        duration = Config.Police.BlipDuration
                    })
                end)
                dispatchSuccess = ok
                if not ok and Config.Debug then
                    print(("[DPS Hookers] custom dispatch error: %s"):format(tostring(err)))
                end

            elseif Config.Police.DispatchType == 'none' then
                dispatchSuccess = true
            end

            if Config.Debug then
                print(("[DPS Hookers] Police dispatched for %s at %s (Risk was %d%%, Dispatch: %s)"):format(
                    GetPlayerName(src),
                    streetName,
                    riskChance,
                    dispatchSuccess and 'success' or 'failed'
                ))
            end
        end

        -- Notify player immediately that they might have been seen
        TriggerClientEvent('dps-hookers:client:policeNotified', src, {
            chance = riskChance,
            reasons = reasons,
            delayed = dispatchDelay > 0
        })

        -- Send dispatch with delay (or immediately if no delay)
        if dispatchDelay > 0 then
            SetTimeout(dispatchDelay, sendDispatch)
        else
            sendDispatch()
        end
    end
end)

--[[ ===================================================== ]]--
--[[                  PLAYER CLEANUP                       ]]--
--[[ ===================================================== ]]--

-- Clean up on player disconnect
AddEventHandler('playerDropped', function()
    local src = source

    -- Clear cooldowns
    if policeAlertCooldowns[src] then
        policeAlertCooldowns[src] = nil
    end

    -- Clear active services
    if activeServices[src] then
        activeServices[src] = nil
    end
end)

print("^2[DPS Hookers]^7 Server initialized successfully")
