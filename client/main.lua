--[[ ===================================================== ]]--
--[[       DPS Hookers - Client Controller                ]]--
--[[       Handles NPCs, animations, police rolls         ]]--
--[[ ===================================================== ]]--

-- State tracking
local hooker = nil
local pimp = nil
local hookerBlip = nil
local isSignaling = false
local isBusy = false
local ageVerified = false

-- Performance: Cache distances for sleep optimization
local SLEEP_FAR = 2000       -- Far from any interaction point
local SLEEP_MEDIUM = 500     -- Within medium range
local SLEEP_NEAR = 100       -- Close to NPC but not interacting
local SLEEP_ACTIVE = 5       -- Actively interacting

-- Distance thresholds
local DIST_FAR = 100.0       -- Beyond this = long sleep
local DIST_MEDIUM = 50.0     -- Within this = medium sleep
local DIST_NEAR = 15.0       -- Within this = short sleep

--[[ ===================================================== ]]--
--[[                  UTILITY FUNCTIONS                    ]]--
--[[ ===================================================== ]]--

--- Load model with waiting
---@param model string Model hash or name
local function loadModel(model)
    local modelHash = type(model) == 'string' and joaat(model) or model
    if not IsModelValid(modelHash) then return false end

    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end

    return HasModelLoaded(modelHash)
end

--- Load animation dictionary
---@param dict string Animation dictionary name
local function loadAnimDict(dict)
    RequestAnimDict(dict)
    local timeout = 0
    while not HasAnimDictLoaded(dict) and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end

    return HasAnimDictLoaded(dict)
end

--- Play animation on entity
---@param entity number Entity handle
---@param dict string Animation dictionary
---@param name string Animation name
local function playAnim(entity, dict, name)
    if not DoesEntityExist(entity) or IsEntityDead(entity) then return end

    if loadAnimDict(dict) then
        TaskPlayAnim(entity, dict, name, 1.0, -1.0, -1, 1, 1, true, true, true)
    end
end

--- Draw 3D text above coordinates
---@param coords vector3 Coordinates
---@param text string Text to display
local function draw3DText(coords, text)
    local onScreen, screenX, screenY = World3dToScreen2d(coords.x, coords.y, coords.z)

    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(true)
        AddTextComponentString(text)
        DrawText(screenX, screenY)

        local factor = (string.len(text)) / 370
        DrawRect(screenX, screenY + 0.0125, 0.015 + factor, 0.03, 41, 11, 41, 68)
    end
end

--[[ ===================================================== ]]--
--[[                    NPC MANAGEMENT                     ]]--
--[[ ===================================================== ]]--

--- Delete hooker NPC with delay
local function deleteHooker()
    if not hooker then return end

    local hookerEntity = hooker
    local randomDelay = math.random(5000, 10000)

    SetTimeout(randomDelay, function()
        if DoesEntityExist(hookerEntity) then
            SetEntityAsMissionEntity(hookerEntity, true, true)
            DeleteEntity(hookerEntity)
        end
    end)

    hooker = nil

    if hookerBlip then
        RemoveBlip(hookerBlip)
        hookerBlip = nil
    end
end

--- Create hooker NPC at spawn location
local function createHooker()
    if hooker then
        lib.notify({
            title = 'DPS Hookers',
            description = lib.locale('notifications.already_busy'),
            type = 'error'
        })
        return
    end

    -- Random model selection
    local modelIndex = math.random(1, #Config.HookerModels)
    local model = Config.HookerModels[modelIndex]

    if not loadModel(model) then
        lib.notify({
            title = 'DSRP Hookers',
            description = 'Failed to load hooker model',
            type = 'error'
        })
        return
    end

    -- Create ped
    local coords = Config.HookerSpawn
    hooker = CreatePed(0, model, coords.x, coords.y, coords.z - 1.0, coords.w, true, true)

    if not DoesEntityExist(hooker) then return end

    -- Configure ped
    SetBlockingOfNonTemporaryEvents(hooker, true)
    SetEntityInvincible(hooker, true)
    FreezeEntityPosition(hooker, true)
    TaskStartScenarioInPlace(hooker, "WORLD_HUMAN_SMOKING", 0, false)

    -- Create blip
    hookerBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(hookerBlip, 280)
    SetBlipScale(hookerBlip, 0.8)
    SetBlipColour(hookerBlip, 48)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Hooker")
    EndTextCommandSetBlipName(hookerBlip)

    -- Set waypoint
    SetNewWaypoint(coords.x, coords.y)

    lib.notify({
        title = 'DPS Hookers',
        description = lib.locale('hooker.approaching'),
        type = 'success'
    })

    SetModelAsNoLongerNeeded(model)
end

--- Create pimp NPC at strip club
local function createPimp()
    if pimp then return end

    local model = Config.PimpModel
    if not loadModel(model) then return end

    loadAnimDict("mini@strip_club@idles@bouncer@base")

    local coords = Config.PimpLocation
    pimp = CreatePed(1, model, coords.x, coords.y, coords.z - 1.0, coords.w, false, true)

    if not DoesEntityExist(pimp) then return end

    -- Configure pimp
    FreezeEntityPosition(pimp, true)
    SetEntityInvincible(pimp, true)
    SetBlockingOfNonTemporaryEvents(pimp, true)
    TaskPlayAnim(pimp, "mini@strip_club@idles@bouncer@base", "base", 8.0, 0.0, -1, 1, 0, 0, 0, 0)

    -- Add ox_target interaction
    exports.ox_target:addLocalEntity(pimp, {
        {
            name = 'dps_hooker_pimp',
            icon = lib.locale('pimp.target_icon'),
            label = lib.locale('pimp.target_label'),
            onSelect = function()
                createHooker()
            end,
            canInteract = function()
                return hooker == nil and GetVehiclePedIsIn(PlayerPedId(), false) == 0
            end,
            distance = 2.5
        }
    })

    SetModelAsNoLongerNeeded(model)
end

--- Delete pimp NPC
local function deletePimp()
    if not pimp then return end

    if DoesEntityExist(pimp) then
        SetEntityAsMissionEntity(pimp, true, true)
        DeleteEntity(pimp)
    end

    pimp = nil
end

--[[ ===================================================== ]]--
--[[                  SERVICE FUNCTIONS                    ]]--
--[[ ===================================================== ]]--

--- Make hooker enter player's vehicle
---@param vehicle number Vehicle handle
local function hookerEnterVehicle(vehicle)
    if not hooker or not DoesEntityExist(hooker) then return end

    isSignaling = true
    isBusy = true

    -- Freeze vehicle while hooker gets in
    FreezeEntityPosition(vehicle, true)

    -- Voice line
    PlayAmbientSpeech1(hooker, "Generic_Hows_It_Going", "Speech_Params_Force")

    -- Unfreeze hooker and make her get in
    FreezeEntityPosition(hooker, false)
    SetEntityAsMissionEntity(hooker, true, true)
    SetBlockingOfNonTemporaryEvents(hooker, true)
    TaskEnterVehicle(hooker, vehicle, -1, 1, 1.0, 1, 0)  -- Seat 1 = passenger

    -- Remove blip
    if hookerBlip then
        RemoveBlip(hookerBlip)
        hookerBlip = nil
    end

    -- Wait for hooker to get in
    local timeout = 0
    while not IsPedInAnyVehicle(hooker, false) and timeout < 10000 do
        Wait(100)
        timeout = timeout + 100
    end

    FreezeEntityPosition(vehicle, false)
    isBusy = false

    lib.notify({
        title = 'DPS Hookers',
        description = lib.locale('hooker.get_in'),
        type = 'info'
    })
end

--- Make hooker leave vehicle
---@param vehicle number Vehicle handle
local function hookerLeaveVehicle(vehicle)
    if not hooker or not DoesEntityExist(hooker) then return end

    isSignaling = false
    TaskLeaveVehicle(hooker, vehicle, 0)
    SetPedAsNoLongerNeeded(hooker)

    deleteHooker()
end

--- Perform blowjob service
local function performBlowjob()
    if not hooker or isBusy then return end

    isBusy = true
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)

    -- Roll for police BEFORE service starts
    TriggerServerEvent('dps-hookers:server:policeRoll', coords)

    -- Progress bar with animations
    loadAnimDict("oddjobs@towing")

    -- Start animations
    playAnim(hooker, "oddjobs@towing", "f_blow_job_loop")
    playAnim(playerPed, "oddjobs@towing", "m_blow_job_loop")

    local success = lib.progressCircle({
        duration = Config.Animations.BlowjobDuration,
        position = 'bottom',
        label = lib.locale('hooker.activity_blowjob'),
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true
        }
    })

    -- Clear animations
    ClearPedTasks(playerPed)
    ClearPedTasks(hooker)

    if success then
        -- Voice lines
        PlayAmbientSpeech1(hooker, "Sex_Finished", "Speech_Params_Force_Shouted_Clear")
        Wait(2000)
        PlayAmbientSpeech1(hooker, "Hooker_Offer_Again", "Speech_Params_Force_Shouted_Clear")
    else
        lib.notify({
            title = 'DPS Hookers',
            description = lib.locale('notifications.cancelled'),
            type = 'error'
        })
    end

    isBusy = false
end

--- Perform sex service
local function performSex()
    if not hooker or isBusy then return end

    isBusy = true
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)

    -- Roll for police BEFORE service starts
    TriggerServerEvent('dps-hookers:server:policeRoll', coords)

    -- Progress bar with animations
    loadAnimDict("mini@prostitutes@sexlow_veh")

    -- Start animations
    playAnim(hooker, "mini@prostitutes@sexlow_veh", "low_car_sex_loop_female")
    playAnim(playerPed, "mini@prostitutes@sexlow_veh", "low_car_sex_loop_player")

    local success = lib.progressCircle({
        duration = Config.Animations.SexDuration,
        position = 'bottom',
        label = lib.locale('hooker.activity_sex'),
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true
        }
    })

    -- Clear animations
    ClearPedTasks(playerPed)
    ClearPedTasks(hooker)

    if success then
        -- Voice lines
        PlayAmbientSpeech1(hooker, "Sex_Finished", "Speech_Params_Force_Shouted_Clear")
        Wait(2000)
        PlayAmbientSpeech1(hooker, "Hooker_Offer_Again", "Speech_Params_Force_Shouted_Clear")
    else
        lib.notify({
            title = 'DPS Hookers',
            description = lib.locale('notifications.cancelled'),
            type = 'error'
        })
    end

    isBusy = false
end

--[[ ===================================================== ]]--
--[[                    CLIENT EVENTS                      ]]--
--[[ ===================================================== ]]--

--- Handle age restriction
RegisterNetEvent('dps-hookers:client:ageRestricted', function()
    lib.notify({
        title = lib.locale('age_verification.title'),
        description = lib.locale('age_verification.rejected'),
        type = 'error',
        duration = 10000
    })
end)

--- Handle successful join
RegisterNetEvent('dps-hookers:client:onJoin', function(data)
    if data.status then
        ageVerified = true
        createPimp()
    end
end)

--- Handle service action from server
RegisterNetEvent('dps-hookers:client:action', function(data)
    if not data.status then return end

    if data.type == 'blowjob' then
        performBlowjob()
    elseif data.type == 'havesex' then
        performSex()
    end
end)

--- Handle police notification
RegisterNetEvent('dps-hookers:client:policeNotified', function(data)
    lib.notify({
        title = 'DPS Hookers',
        description = lib.locale('police.witness_alert'),
        type = 'warning',
        duration = 5000
    })
end)

--[[ ===================================================== ]]--
--[[                   MAIN THREAD LOOP                    ]]--
--[[ ===================================================== ]]--

--- Calculate optimal sleep time based on distance to relevant points
---@param playerCoords vector3
---@return number sleep time in ms
local function calculateSleepTime(playerCoords)
    -- If we have an active hooker, prioritize that distance
    if hooker and DoesEntityExist(hooker) then
        local hookerCoords = GetEntityCoords(hooker)
        local dist = #(playerCoords - hookerCoords)

        if dist < 5.0 then return SLEEP_ACTIVE end
        if dist < DIST_NEAR then return SLEEP_NEAR end
        if dist < DIST_MEDIUM then return SLEEP_MEDIUM end
    end

    -- Check distance to pimp location
    local pimpDist = #(playerCoords - vector3(Config.PimpLocation.x, Config.PimpLocation.y, Config.PimpLocation.z))

    if pimpDist < DIST_NEAR then return SLEEP_NEAR end
    if pimpDist < DIST_MEDIUM then return SLEEP_MEDIUM end
    if pimpDist < DIST_FAR then return SLEEP_FAR end

    -- Very far from everything
    return SLEEP_FAR
end

--- Check if hooker should be cleaned up (player too far)
local function checkHookerCleanup()
    if not hooker or not DoesEntityExist(hooker) then return end
    if isBusy then return end  -- Don't cleanup during service

    local playerCoords = GetEntityCoords(PlayerPedId())
    local hookerCoords = GetEntityCoords(hooker)
    local dist = #(playerCoords - hookerCoords)

    -- If player drove too far away (150+ units) and hooker isn't in vehicle, cleanup
    if dist > 150.0 and not IsPedInAnyVehicle(hooker, false) then
        lib.notify({
            title = 'DPS Hookers',
            description = 'The hooker got tired of waiting and left.',
            type = 'info'
        })
        deleteHooker()
    end
end

CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local sleep = calculateSleepTime(playerCoords)

        if ageVerified and hooker and DoesEntityExist(hooker) then
            -- Check for cleanup (player abandoned hooker)
            checkHookerCleanup()

            local vehicle = GetVehiclePedIsIn(playerPed, false)
            local isDriver = vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == playerPed

            if vehicle ~= 0 and not isBusy then
                -- Hooker not in vehicle yet - waiting at spawn
                if not IsPedInAnyVehicle(hooker, false) then
                    local vehicleCoords = GetEntityCoords(vehicle)
                    local hookerCoords = GetEntityCoords(hooker)
                    local dist = #(vehicleCoords - hookerCoords)

                    if dist < 5.0 then
                        sleep = SLEEP_ACTIVE  -- Need fast response for controls

                        if not isSignaling and isDriver then
                            draw3DText(hookerCoords + vector3(0, 0, 1.0), lib.locale('hooker.press_signal', {
                                key = Config.Controls.Signal.label
                            }))
                        end

                        -- Press E to signal hooker
                        if IsControlJustReleased(0, Config.Controls.Signal.key) and isDriver then
                            hookerEnterVehicle(vehicle)
                        end
                    end

                -- Hooker is in vehicle - show service options
                elseif IsPedInAnyVehicle(hooker, false) and IsVehicleStopped(vehicle) then
                    sleep = SLEEP_ACTIVE  -- Need fast response for controls

                    if isDriver then
                        -- Blowjob (Arrow Up)
                        if IsControlJustReleased(0, Config.Controls.Blowjob.key) then
                            TriggerServerEvent('dps-hookers:server:pay', {type = 'blowjob'})
                        end

                        -- Sex (Arrow Down)
                        if IsControlJustReleased(0, Config.Controls.Sex.key) then
                            TriggerServerEvent('dps-hookers:server:pay', {type = 'havesex'})
                        end

                        -- Dismiss (Arrow Left/Right)
                        if IsControlJustReleased(0, Config.Controls.Dismiss.key) or
                           IsControlJustReleased(0, Config.Controls.Dismiss.alt) then
                            hookerLeaveVehicle(vehicle)
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

--[[ ===================================================== ]]--
--[[                  RESOURCE LIFECYCLE                   ]]--
--[[ ===================================================== ]]--

--- Trigger server on resource start
AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        TriggerServerEvent('dps-hookers:server:onJoin')
    end
end)

--- Clean up on resource stop
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        deleteHooker()
        deletePimp()
    end
end)

--- Trigger server when player loads
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('dps-hookers:server:onJoin')
end)

--- Clean up when player unloads (logout/disconnect)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    deleteHooker()
    deletePimp()
    ageVerified = false
end)

print("^2[DPS Hookers]^7 Client initialized successfully")