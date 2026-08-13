--[[ ===================================================== ]]--
--[[       DPS Hookers - Server Controller                ]]--
--[[       Handles payments, age verification, police     ]]--
--[[ ===================================================== ]]--

-- Police alert cooldown tracking (per player)
local policeAlertCooldowns = {}

-- Active service tracking (prevent double-charge exploits)
local activeServices = {}

-- Active hooker tracking (per player). Set by the client when a hooker has
-- actually entered the player's vehicle; required precondition for server:pay
-- and server:policeRoll so those events can't be triggered directly to farm
-- payments / stress relief / dispatch without going through the interaction.
local activeHookers = {}

--[[ ===================================================== ]]--
--[[                  UTILITY FUNCTIONS                    ]]--
--[[ ===================================================== ]]--

--- Get player object (uses Bridge)
---@param src number Player source ID
---@return table|nil Player object or nil
local function getPlayer(src)
    return Bridge.GetPlayer(src)
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

    local birthdate = Bridge.GetBirthdate(src)
    if not birthdate then return true end

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
--- DPSRP 1.5: Uses jg-hud state bags
---@param src number Player source ID
---@param amount number Amount of stress to remove
local function removeStress(src, amount)
    if Config.StressSystem == 'jg-hud' then
        -- jg-hud uses state bags for stress
        local player = Player(src)
        if player then
            local currentStress = player.state.stress or 0
            local newStress = math.max(0, currentStress - amount)
            player.state:set('stress', newStress, true)
        end
    elseif Config.StressSystem == 'qb-hud' then
        TriggerClientEvent('hud:client:RelieveStress', src, amount)
    elseif Config.StressSystem == 'custom' then
        -- Custom stress event - configure in config.lua
        if Config.CustomStressEvent then
            TriggerClientEvent(Config.CustomStressEvent, src, amount)
        end
    elseif Config.StressSystem ~= 'none' then
        -- Default fallback: try common stress event
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

--- Client reports whether it currently has an active hooker in the vehicle.
--- This is the state precondition consumed by server:pay / server:policeRoll.
RegisterServerEvent('dps-hookers:server:setHookerState', function(active)
    local src = source
    activeHookers[src] = active and true or nil
end)

--- Handle payment for services
RegisterServerEvent('dps-hookers:server:pay', function(data)
    local src = source
    local player = getPlayer(src)

    if not player then return end

    -- Security: Validate payload shape
    if type(data) ~= 'table' then return end

    -- Security (M2): re-verify the 18+ age gate here. onJoin is not enough -
    -- triggering this event directly would otherwise skip the gate entirely.
    if Config.AgeVerification and isPlayerUnderage(src) then
        TriggerClientEvent('dps-hookers:client:ageRestricted', src)
        return
    end

    -- Security (M4): require an active hooker (client must have gone through
    -- the signal -> enter-vehicle flow). Blocks direct-trigger farming.
    if not activeHookers[src] then
        if Config.Debug then
            print(("[DPS Hookers] pay rejected for %s: no active hooker"):format(GetPlayerName(src)))
        end
        return
    end

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
    local cash = Bridge.GetMoney(src, 'cash')

    if cash < cost then
        notify(src, lib.locale('notifications.no_cash'), 'error')
        return
    end

    -- Remove money (server-side validation)
    local success = Bridge.RemoveMoney(src, 'cash', cost, 'dps-hookers-service')

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
--- Payload (all computed client-side, where the world natives actually work):
---   data.coords {x,y,z}, data.witnessCount, data.riskChance, data.location, data.streetName
--- The server does NOT trust these blindly: it re-checks the age gate and the
--- active-service state, cross-checks coords against the player's real position,
--- clamps witnessCount + riskChance, and performs the authoritative roll itself.
RegisterServerEvent('dps-hookers:server:policeRoll', function(data)
    local src = source

    if not Config.Police.Enabled then return end
    if type(data) ~= 'table' then return end
    if isOnPoliceCooldown(src) then return end

    -- Security (M2): re-verify the 18+ gate on this direct-triggerable event too
    if Config.AgeVerification and isPlayerUnderage(src) then return end

    -- Security (M4): the roll only makes sense during an active paid service.
    -- pay() sets service state before dispatching the client action that leads
    -- here, so a legitimate roll always has an active service.
    if not isInService(src) then
        if Config.Debug then
            print(("[DPS Hookers] policeRoll rejected for %s: no active service"):format(GetPlayerName(src)))
        end
        return
    end

    -- Validate + convert client coords to a vector3
    local coords
    local c = data.coords
    if type(c) == 'vector3' then
        coords = c
    elseif type(c) == 'table' and tonumber(c.x) and tonumber(c.y) and tonumber(c.z) then
        coords = vector3(c.x + 0.0, c.y + 0.0, c.z + 0.0)
    else
        return
    end

    -- Security (H2): cross-check the reported coords against the player's real
    -- server-known position. If they are wildly off (spoofed), fall back to the
    -- authoritative position and drop the (now untrustworthy) street name.
    local streetName = type(data.streetName) == 'string' and data.streetName or 'Unknown Location'
    local ped = GetPlayerPed(src)
    if ped and ped ~= 0 then
        local realCoords = GetEntityCoords(ped)
        if realCoords and (realCoords.x ~= 0.0 or realCoords.y ~= 0.0) then
            if #(realCoords - coords) > 75.0 then
                if Config.Debug then
                    print(("[DPS Hookers] policeRoll coords mismatch for %s - using server position"):format(GetPlayerName(src)))
                end
                coords = realCoords
                streetName = 'Unknown Location'
            end
        end
    end

    -- Clamp witness count (H2: client-supplied, so bound it)
    local witnessCount = math.max(0, math.min(math.floor(tonumber(data.witnessCount) or 0), 50))

    -- Witness check: If enabled, require at least 1 witness NPC
    if Config.Police.RequireWitness and witnessCount < 1 then
        if Config.Debug then
            print(("[DPS Hookers] No witnesses for %s - no dispatch"):format(GetPlayerName(src)))
        end
        return
    end

    -- Clamp the client-computed risk to a sane range (H1/H2)
    local riskChance = math.max(0, math.min(math.floor(tonumber(data.riskChance) or 0), 100))

    -- reasons table is rebuilt server-side from validated inputs (never trusted wholesale)
    local reasons = { location = type(data.location) == 'string' and data.location or nil }

    -- Bonus risk for multiple witnesses (scaled by multiplier)
    if witnessCount > 0 then
        local multiplier = Config.Police.WitnessMultiplier or 1.0
        local witnessBonus = math.min(math.floor(witnessCount * 5 * multiplier), 40)  -- Scaled per witness, max +40%
        riskChance = math.min(riskChance + witnessBonus, 100)
        reasons.witnesses = witnessCount
        reasons.witnessBonus = witnessBonus
        reasons.witnessMultiplier = multiplier
    end

    -- Roll the dice (authoritative, server-side)
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
                -- qs-dispatch must be triggered from client-side
                TriggerClientEvent('dps-hookers:client:triggerDispatch', src, {
                    coords = coords,
                    street = streetName,
                    code = lib.locale('police.dispatch_code'),
                    title = lib.locale('police.dispatch_title'),
                    message = lib.locale('police.dispatch_message'),
                    blipTime = Config.Police.BlipDuration
                })
                dispatchSuccess = true

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

    -- Clear active hooker state
    if activeHookers[src] then
        activeHookers[src] = nil
    end
end)

--[[ ===================================================== ]]--
--[[              DISPATCH SOFT-DETECTION (M1)             ]]--
--[[ ===================================================== ]]--

-- If the configured dispatch resource isn't actually running, fall back to
-- 'none' (a clean no-op) instead of erroring at dispatch time. On a box with
-- no dispatch resource installed (e.g. lb-phone only), this makes the police
-- system silently no-op rather than hard-fault.
CreateThread(function()
    Wait(2000)  -- give other resources time to start

    if not Config.Police.Enabled then return end

    local dispatchResources = {
        ['ps-dispatch'] = 'ps-dispatch',
        ['cd_dispatch'] = 'cd_dispatch',
        ['qs-dispatch'] = 'qs-dispatch'
    }

    local dt = Config.Police.DispatchType
    local resName = dispatchResources[dt]

    -- 'custom' and 'none' can't be resource-probed; leave them alone.
    if resName and GetResourceState(resName) ~= 'started' then
        print(("^3[DPS Hookers]^7 Dispatch '%s' is not started - falling back to 'none' (no-op). Set Config.Police.DispatchType to a running dispatch resource to enable alerts."):format(dt))
        Config.Police.DispatchType = 'none'
    end
end)

print("^2[DPS Hookers]^7 Server initialized successfully")
