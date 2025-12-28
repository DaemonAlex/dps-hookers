--[[ ===================================================== ]]--
--[[                  DPS Hookers Config                  ]]--
--[[              Adult RP System with Police AI          ]]--
--[[ ===================================================== ]]--

Config = {}

-- Set your locale file (locales/en.json)
lib.locale()

--[[ ===================================================== ]]--
--[[                    GENERAL SETTINGS                   ]]--
--[[ ===================================================== ]]--

-- Debug mode (shows police roll results in console)
Config.Debug = false

-- Age verification (18+ content)
Config.AgeVerification = true  -- Require age confirmation on first use

-- Stress system integration
-- Options: 'qb-hud', 'qbx-hud', 'custom', 'none'
Config.StressSystem = 'qb-hud'
Config.CustomStressEvent = nil  -- Set if using 'custom' (e.g., 'myHud:removeStress')

-- NPC Models
Config.HookerModels = {
    's_f_y_hooker_01',
    's_f_y_hooker_02',
    's_f_y_hooker_03'
}

Config.PimpModel = 's_m_m_bouncer_01'

-- NPC Spawn Locations
Config.HookerSpawn = vector4(136.2074, -1278.8458, 29.3648, 299.4893)  -- Strip club parking
Config.PimpLocation = vector4(117.3872, -1305.0110, 29.2328, 217.0572) -- Strip club entrance

--[[ ===================================================== ]]--
--[[                   PRICING & SERVICES                  ]]--
--[[ ===================================================== ]]--

Config.Prices = {
    Blowjob = 100,
    Sex = 500
}

-- Stress relief (random amount per service)
Config.StressRelief = {
    Min = 2,
    Max = 4
}

--[[ ===================================================== ]]--
--[[                  INTERACTION CONTROLS                 ]]--
--[[ ===================================================== ]]--

-- Key controls for vehicle interactions
-- Reference: https://docs.fivem.net/docs/game-references/controls/
Config.Controls = {
    Signal = {
        label = 'E',
        key = 38
    },
    Blowjob = {
        label = 'ARROW UP',
        key = 172
    },
    Sex = {
        label = 'ARROW DOWN',
        key = 173
    },
    Dismiss = {
        label = 'ARROW LEFT',
        key = 174,
        alt = 175  -- ARROW RIGHT also works
    }
}

--[[ ===================================================== ]]--
--[[              POLICE DISPATCH SYSTEM                   ]]--
--[[   Smart AI that considers location & time of day     ]]--
--[[ ===================================================== ]]--

Config.Police = {
    Enabled = true,

    -- Dispatch system to use
    -- Options: 'ps-dispatch', 'cd_dispatch', 'qs-dispatch', 'custom', 'none'
    DispatchType = 'ps-dispatch',

    -- Base chance of police being called (percentage)
    BaseChance = 15,

    -- Location-based risk modifiers
    -- These add/subtract from base chance based on where you are
    LocationRisk = {
        -- High-traffic areas = more witnesses = higher risk
        Busy = {
            enabled = true,
            modifier = 25,  -- +25% in busy downtown areas
            zones = {
                -- Downtown/Vinewood
                {coords = vector3(215.0, -810.0, 30.0), radius = 200.0},
                {coords = vector3(-200.0, -850.0, 30.0), radius = 150.0},
                -- Legion Square
                {coords = vector3(195.0, -935.0, 30.0), radius = 100.0},
                -- Del Perro Pier
                {coords = vector3(-1650.0, -1080.0, 13.0), radius = 150.0}
            }
        },

        -- Alleys and secluded spots = fewer witnesses = lower risk
        Secluded = {
            enabled = true,
            modifier = -15,  -- -15% in alleys/isolated areas
            -- Auto-detected based on distance from main roads
            -- Areas with few nearby peds/vehicles
            requiresCheck = true
        },

        -- Industrial areas = moderate risk
        Industrial = {
            enabled = true,
            modifier = -5,  -- -5% in industrial zones
            zones = {
                -- Docks
                {coords = vector3(1200.0, -3000.0, 5.0), radius = 300.0},
                -- Elysian Island
                {coords = vector3(285.0, -3050.0, 5.0), radius = 400.0},
                -- La Puerta industrial
                {coords = vector3(-500.0, -1800.0, 20.0), radius = 200.0}
            }
        },

        -- Strip club area = lower risk (expected activity)
        StripClub = {
            enabled = true,
            modifier = -10,  -- -10% near strip club
            zones = {
                {coords = vector3(127.0, -1290.0, 29.0), radius = 100.0}  -- Vanilla Unicorn
            }
        },

        -- Residential areas = moderate risk
        Residential = {
            enabled = true,
            modifier = 5,  -- +5% in neighborhoods
            zones = {
                -- Vinewood Hills
                {coords = vector3(100.0, 500.0, 140.0), radius = 300.0},
                -- Rockford Hills
                {coords = vector3(-800.0, 180.0, 70.0), radius = 250.0},
                -- Mirror Park
                {coords = vector3(1100.0, -650.0, 60.0), radius = 200.0}
            }
        }
    },

    -- Time-based risk modifiers
    TimeRisk = {
        -- Daytime = more people around = higher risk
        Day = {
            enabled = true,
            modifier = 10,  -- +10% during day (06:00-18:00)
            startHour = 6,
            endHour = 18
        },

        -- Evening = moderate risk
        Evening = {
            enabled = true,
            modifier = 0,  -- No modifier (18:00-22:00)
            startHour = 18,
            endHour = 22
        },

        -- Night = fewer witnesses = lower risk
        Night = {
            enabled = true,
            modifier = -8,  -- -8% at night (22:00-06:00)
            startHour = 22,
            endHour = 6
        }
    },

    -- Additional factors
    Weather = {
        enabled = true,
        -- Rain/fog reduces visibility = lower risk
        badWeather = {
            modifier = -5,
            types = {'RAIN', 'THUNDER', 'CLEARING', 'FOGGY'}
        }
    },

    -- Cooldown between police alerts (seconds)
    -- Prevents spam if multiple services in short time
    Cooldown = 300,  -- 5 minutes

    -- Distance police will be notified (for dispatch radius)
    BlipRadius = 150.0,

    -- How long the blip stays on police map (seconds)
    BlipDuration = 120
}

--[[ ===================================================== ]]--
--[[                 ANIMATION SETTINGS                    ]]--
--[[ ===================================================== ]]--

Config.Animations = {
    -- Progress bar duration (milliseconds)
    BlowjobDuration = 30000,  -- 30 seconds
    SexDuration = 30000,      -- 30 seconds

    -- Progress bar settings
    ProgressBar = {
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disableMovement = true,
        disableCombat = true,
        disableVehicle = false
    }
}

--[[ ===================================================== ]]--
--[[                  UTILITY FUNCTIONS                    ]]--
--[[ ===================================================== ]]--

-- Calculate total police chance based on location and time
function Config.CalculatePoliceRisk(playerCoords)
    if not Config.Police.Enabled then return 0 end

    local totalRisk = Config.Police.BaseChance
    local reasons = {base = Config.Police.BaseChance}

    -- Check location-based modifiers
    local function isInZone(coords, zones)
        for _, zone in ipairs(zones) do
            if #(coords - zone.coords) <= zone.radius then
                return true
            end
        end
        return false
    end

    -- Busy areas
    if Config.Police.LocationRisk.Busy.enabled then
        if isInZone(playerCoords, Config.Police.LocationRisk.Busy.zones) then
            totalRisk = totalRisk + Config.Police.LocationRisk.Busy.modifier
            reasons.location = 'Busy area'
            reasons.locationMod = Config.Police.LocationRisk.Busy.modifier
        end
    end

    -- Industrial areas
    if Config.Police.LocationRisk.Industrial.enabled then
        if isInZone(playerCoords, Config.Police.LocationRisk.Industrial.zones) then
            totalRisk = totalRisk + Config.Police.LocationRisk.Industrial.modifier
            reasons.location = 'Industrial zone'
            reasons.locationMod = Config.Police.LocationRisk.Industrial.modifier
        end
    end

    -- Strip club
    if Config.Police.LocationRisk.StripClub.enabled then
        if isInZone(playerCoords, Config.Police.LocationRisk.StripClub.zones) then
            totalRisk = totalRisk + Config.Police.LocationRisk.StripClub.modifier
            reasons.location = 'Strip club area'
            reasons.locationMod = Config.Police.LocationRisk.StripClub.modifier
        end
    end

    -- Residential
    if Config.Police.LocationRisk.Residential.enabled then
        if isInZone(playerCoords, Config.Police.LocationRisk.Residential.zones) then
            totalRisk = totalRisk + Config.Police.LocationRisk.Residential.modifier
            reasons.location = 'Residential area'
            reasons.locationMod = Config.Police.LocationRisk.Residential.modifier
        end
    end

    -- Secluded check (if no other zone matched and enabled)
    if Config.Police.LocationRisk.Secluded.enabled and not reasons.location then
        -- Check if area is secluded (few nearby peds/vehicles)
        local nearbyPeds = #(GetGamePool('CPed'))
        local nearbyVehicles = #(GetGamePool('CVehicle'))

        if nearbyPeds < 5 and nearbyVehicles < 3 then
            totalRisk = totalRisk + Config.Police.LocationRisk.Secluded.modifier
            reasons.location = 'Secluded area'
            reasons.locationMod = Config.Police.LocationRisk.Secluded.modifier
        end
    end

    -- Time-based modifiers
    local currentHour = GetClockHours()

    if Config.Police.TimeRisk.Day.enabled then
        if currentHour >= Config.Police.TimeRisk.Day.startHour and currentHour < Config.Police.TimeRisk.Day.endHour then
            totalRisk = totalRisk + Config.Police.TimeRisk.Day.modifier
            reasons.time = 'Daytime'
            reasons.timeMod = Config.Police.TimeRisk.Day.modifier
        end
    end

    if Config.Police.TimeRisk.Evening.enabled then
        if currentHour >= Config.Police.TimeRisk.Evening.startHour and currentHour < Config.Police.TimeRisk.Evening.endHour then
            totalRisk = totalRisk + Config.Police.TimeRisk.Evening.modifier
            reasons.time = 'Evening'
            reasons.timeMod = Config.Police.TimeRisk.Evening.modifier
        end
    end

    if Config.Police.TimeRisk.Night.enabled then
        if currentHour >= Config.Police.TimeRisk.Night.startHour or currentHour < Config.Police.TimeRisk.Night.endHour then
            totalRisk = totalRisk + Config.Police.TimeRisk.Night.modifier
            reasons.time = 'Night'
            reasons.timeMod = Config.Police.TimeRisk.Night.modifier
        end
    end

    -- Weather modifier
    if Config.Police.Weather.enabled then
        local weather = GetPrevWeatherTypeHashName()
        for _, weatherType in ipairs(Config.Police.Weather.badWeather.types) do
            if weather == GetHashKey(weatherType) then
                totalRisk = totalRisk + Config.Police.Weather.badWeather.modifier
                reasons.weather = 'Bad weather'
                reasons.weatherMod = Config.Police.Weather.badWeather.modifier
                break
            end
        end
    end

    -- Ensure risk is between 0-100
    totalRisk = math.max(0, math.min(100, totalRisk))

    return totalRisk, reasons
end

return Config