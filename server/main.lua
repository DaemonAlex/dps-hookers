--[[ ===================================================== ]]--
--[[       DSRP Hookers - Server Controller               ]]--
--[[       Handles payments, age verification, police     ]]--
--[[ ===================================================== ]]--

-- Police alert cooldown tracking (per player)
local policeAlertCooldowns = {}

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
        title = 'DSRP Hookers',
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

    local birthdate = player.PlayerData.charinfo.birthdate
    if not birthdate then return true end

    -- Parse birthdate (format: YYYY-MM-DD)
    local birthdateParts = {}
    for value in string.gmatch(birthdate, "[^-]+") do
        table.insert(birthdateParts, tonumber(value))
    end

    -- Parse current date
    local currentDate = {}
    for value in string.gmatch(os.date("%Y-%m-%d"), "[^-]+") do
        table.insert(currentDate, tonumber(value))
    end

    -- Calculate age (using -4 offset as per original script)
    local age = currentDate[1] - birthdateParts[1] - 4

    return age < 18
end

--- Remove player stress
---@param src number Player source ID
---@param amount number Amount of stress to remove
local function removeStress(src, amount)
    -- QBox stress system
    TriggerClientEvent('hud:client:RelieveStress', src, amount)
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

--[[ ===================================================== ]]--
--[[                   SERVER EVENTS                       ]]--
--[[ ===================================================== ]]--

--- Handle player joining/loading the resource
RegisterServerEvent('dsrp-hookers:server:onJoin', function()
    local src = source
    local player = getPlayer(src)

    if not player then return end

    -- Check age verification
    if Config.AgeVerification then
        if isPlayerUnderage(src) then
            print(("[DSRP Hookers] Player %s (%s) is underage - access denied"):format(
                GetPlayerName(src),
                src
            ))
            TriggerClientEvent('dsrp-hookers:client:ageRestricted', src)
            return
        end
    end

    -- Send config to client
    TriggerClientEvent('dsrp-hookers:client:onJoin', src, {
        status = true,
        config = Config
    })
end)

--- Handle payment for services
RegisterServerEvent('dsrp-hookers:server:pay', function(data)
    local src = source
    local player = getPlayer(src)

    if not player then return end

    local serviceType = data.type
    local cost = 0
    local serviceName = ''

    -- Determine cost and service name
    if serviceType == 'blowjob' then
        cost = Config.Prices.Blowjob
        serviceName = 'blowjob'
    elseif serviceType == 'havesex' then
        cost = Config.Prices.Sex
        serviceName = 'sex'
    else
        return
    end

    -- Check if player has enough cash
    local cash = player.PlayerData.money.cash or 0

    if cash < cost then
        notify(src, lib.locale('notifications.no_cash'), 'error')
        return
    end

    -- Remove money
    local success = player.Functions.RemoveMoney('cash', cost)

    if not success then
        notify(src, lib.locale('notifications.no_cash'), 'error')
        return
    end

    -- Notify player of payment
    notify(src, lib.locale('notifications.paid', {
        cost = cost,
        type = serviceName
    }), 'success')

    -- Trigger client-side action (animations, etc.)
    TriggerClientEvent('dsrp-hookers:client:action', src, {
        status = true,
        type = serviceType
    })

    -- Reduce stress after a delay (after service completes)
    local stressAmount = math.random(Config.StressRelief.Min, Config.StressRelief.Max)

    SetTimeout(Config.Animations[serviceType == 'blowjob' and 'BlowjobDuration' or 'SexDuration'], function()
        removeStress(src, stressAmount)
        notify(src, lib.locale('notifications.service_complete'), 'success')
    end)
end)

--- Handle police dispatch roll
RegisterServerEvent('dsrp-hookers:server:policeRoll', function(coords)
    local src = source

    if not Config.Police.Enabled then return end
    if isOnPoliceCooldown(src) then return end

    -- Calculate police risk chance
    local riskChance, reasons = Config.CalculatePoliceRisk(coords)

    -- Roll the dice
    local roll = math.random(1, 100)

    -- Debug logging (optional - remove in production)
    print(("[DSRP Hookers] Police roll for %s: %d/%d (Risk: %d%%)"):format(
        GetPlayerName(src),
        roll,
        100,
        riskChance
    ))

    if roll <= riskChance then
        -- Police were called!
        setPoliceCooldown(src)

        -- Get street name
        local streetHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
        local streetName = GetStreetNameFromHashKey(streetHash)

        -- Trigger police dispatch based on configured system
        if Config.Police.DispatchType == 'ps-dispatch' then
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
        elseif Config.Police.DispatchType == 'cd_dispatch' then
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
        elseif Config.Police.DispatchType == 'qs-dispatch' then
            exports['qs-dispatch']:SuspiciousActivity(coords, lib.locale('police.dispatch_message'))
        elseif Config.Police.DispatchType == 'custom' then
            -- Trigger custom event
            TriggerEvent('police:dispatch', {
                code = lib.locale('police.dispatch_code'),
                title = lib.locale('police.dispatch_title'),
                message = lib.locale('police.dispatch_message'),
                coords = coords,
                street = streetName,
                radius = Config.Police.BlipRadius,
                duration = Config.Police.BlipDuration
            })
        end

        -- Notify player
        TriggerClientEvent('dsrp-hookers:client:policeNotified', src, {
            chance = riskChance,
            reasons = reasons
        })

        -- Debug log
        print(("[DSRP Hookers] Police dispatched for %s at %s (Risk was %d%%)"):format(
            GetPlayerName(src),
            streetName,
            riskChance
        ))
    end
end)

--[[ ===================================================== ]]--
--[[                  PLAYER CLEANUP                       ]]--
--[[ ===================================================== ]]--

-- Clean up cooldown on player disconnect
AddEventHandler('playerDropped', function()
    local src = source
    if policeAlertCooldowns[src] then
        policeAlertCooldowns[src] = nil
    end
end)

print("^2[DSRP Hookers]^7 Server initialized successfully")