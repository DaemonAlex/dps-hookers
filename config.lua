--[[ ===================================================== ]]--
--[[                  DPS Hookers Config                  ]]--
--[[              Adult RP System with Police AI          ]]--
--[[ ===================================================== ]]--

Config = {}

-- Framework: 'auto', 'qb', or 'esx'
-- Auto-detection checks for qb-core first, then es_extended
Config.Framework = 'auto'

-- Set your locale file (locales/en.json)
lib.locale()

--[[ ===================================================== ]]--
--[[                    GENERAL SETTINGS                   ]]--
--[[ ===================================================== ]]--

-- Debug mode (shows police roll results in console)
Config.Debug = false

-- Age verification (18+ content)
-- Checks PlayerData.charinfo.birthdate (supports YYYY-MM-DD and DD/MM/YYYY formats)
-- Set to false if your server handles age gates differently
Config.AgeVerification = true

-- Stress system integration for DPSRP 1.5
-- Options: 'jg-hud' (state bags), 'qb-hud', 'custom', 'none'
Config.StressSystem = 'jg-hud'
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

-- Adjust these to match your server's economy
-- High-inflation servers may want $500/$2000 or higher
Config.Prices = {
    Blowjob = 100,
    Sex = 500
}

-- Stress relief (random amount per service)
-- Higher values because... you know... full release
Config.StressRelief = {
    Min = 15,
    Max = 25
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
    -- Options: 'wasabi_mdt', 'ps-dispatch', 'cd_dispatch', 'qs-dispatch', 'custom', 'none'
    DispatchType = 'wasabi_mdt',

    -- Witness system: Require nearby NPC to "see" the act before dispatch
    RequireWitness = true,
    WitnessRadius = 40.0,  -- How close a ped must be to witness (increased for high-pop)
    WitnessMultiplier = 1.5,  -- Risk multiplier per witness (1.5 = +50% per witness)

    -- Delayed dispatch for secluded areas (simulates bystander finding scene later)
    DelayedDispatch = {
        enabled = true,
        secludedDelay = {min = 30000, max = 60000},  -- 30-60 second delay in secluded areas
        normalDelay = {min = 5000, max = 15000},      -- 5-15 second delay normally
    },

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
        -- Rewards players for finding private spots
        Secluded = {
            enabled = true,
            modifier = -20,  -- -20% in alleys/isolated areas (strong reward)
            -- Auto-detected: <5 nearby peds and <3 nearby vehicles
            requiresCheck = true,
            -- Known safe spots (add your server's popular hideouts)
            knownSpots = {
                -- Back alleys
                {coords = vector3(140.0, -1270.0, 29.0), radius = 30.0},   -- Behind Vanilla Unicorn
                {coords = vector3(-55.0, -1230.0, 28.0), radius = 25.0},   -- Strawberry back alley
                {coords = vector3(485.0, -1310.0, 29.0), radius = 30.0},   -- La Mesa alley
                -- Parking structures (dark corners)
                {coords = vector3(215.0, -785.0, 31.0), radius = 40.0},    -- Legion Square parking
                {coords = vector3(-335.0, -935.0, 31.0), radius = 35.0},   -- Pillbox Hill parking
                -- Under bridges/overpasses
                {coords = vector3(-530.0, -1150.0, 22.0), radius = 50.0},  -- Under Olympic Fwy
                {coords = vector3(725.0, -1275.0, 25.0), radius = 40.0},   -- Under La Mesa overpass
                -- Remote areas
                {coords = vector3(2700.0, 3400.0, 55.0), radius = 100.0},  -- Sandy Shores outskirts
                {coords = vector3(-1820.0, 2050.0, 140.0), radius = 80.0}, -- Zancudo River
            }
        },

        -- Industrial areas = lower risk (fewer civilians)
        Industrial = {
            enabled = true,
            modifier = -12,  -- -12% in industrial zones
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
        -- Stormy nights become the "meta" for these activities
        badWeather = {
            modifier = -10,  -- -10% in rain/fog (stacks with night bonus)
            types = {'RAIN', 'THUNDER', 'CLEARING', 'FOGGY', 'SMOG'}
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
        local isKnownSpot = false

        -- First check known safe spots
        if Config.Police.LocationRisk.Secluded.knownSpots then
            for _, spot in ipairs(Config.Police.LocationRisk.Secluded.knownSpots) do
                if #(playerCoords - spot.coords) <= spot.radius then
                    isKnownSpot = true
                    break
                end
            end
        end

        if isKnownSpot then
            -- Known safe spot - guaranteed secluded bonus
            totalRisk = totalRisk + Config.Police.LocationRisk.Secluded.modifier
            reasons.location = 'Known safe spot'
            reasons.locationMod = Config.Police.LocationRisk.Secluded.modifier
        elseif Config.Police.LocationRisk.Secluded.requiresCheck then
            -- Dynamic check: few nearby peds/vehicles
            local nearbyPeds = #(GetGamePool('CPed'))
            local nearbyVehicles = #(GetGamePool('CVehicle'))

            if nearbyPeds < 5 and nearbyVehicles < 3 then
                totalRisk = totalRisk + Config.Police.LocationRisk.Secluded.modifier
                reasons.location = 'Secluded area'
                reasons.locationMod = Config.Police.LocationRisk.Secluded.modifier
            end
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


--[[ ===================================================== ]]--
--[[   STREET CORNERS (DPS 2026-10-29, Damon's brief)      ]]--
--[[   Girls on the pavement outside the night spots.      ]]--
--[[   Never in the street: see client/corners.lua.        ]]--
--[[ ===================================================== ]]--

-- Game hours the corners are worked. Corners with allDay = true ignore this.
Config.Night = { start = 21, stop = 5 }

-- The street rule: a spot is snapped to the nearest pavement point and refused
-- when a road node is closer than roadNodeMin or a vehicle sits within vehicleMin.
Config.StreetRule = { roadNodeMin = 3.0, vehicleMin = 5.0 }

Config.Corner = {
    spawnRange   = 120.0,  -- a corner comes to life when the player is this close
    despawnRange = 170.0,  -- and goes quiet again beyond this
    callRange    = 12.0,   -- she calls out to players on foot within this
    callCooldown = 60000,  -- ms between call-outs for this player
    attachRange  = 10.0,   -- a car stopped this close gets the E prompt (existing flow)
    detachRange  = 40.0,   -- drive off this far without picking her up and she lets go
    blip         = { sprite = 121, colour = 48, scale = 0.8, label = 'Vanilla Unicorn' }, -- one blip, at the pimp
}

-- What she says to a passer-by (one at random, spoken line + floating text).
Config.CallOuts = {
    "Hey handsome, you lost? I can help you find something.",
    "Long night? Mine's just getting started. Come here.",
    "Don't be shy, sugar, I don't bite. Much.",
    "Looking for company or just looking?",
    "Slow down, baby. Where's the fire?",
    "You look like you could use some attention.",
}

-- style 'low' = WORLD_HUMAN_PROSTITUTE_LOW_CLASS, 'high' = WORLD_HUMAN_PROSTITUTE_HIGH_CLASS.
-- count = girls at that corner. Coordinates are the venue; the pavement snap does the rest.
-- Marked (approximate): Damon's /spot replaces them when he has walked them.
Config.Corners = {
    { label = 'Vanilla Unicorn, Vespucci Blvd', coords = vector3(127.92, -1284.64, 29.28), style = 'low',  count = 2, allDay = true },
    { label = 'Bahama Mamas West',              coords = vector3(-1386.05, -593.02, 30.32), style = 'high', count = 1 },
    { label = 'Tequi-la-la, Vinewood',          coords = vector3(-561.0, 286.0, 82.2),      style = 'low',  count = 1 },
    { label = 'Koi, Vespucci Canals',           coords = vector3(-1034.73, -1484.28, 4.58), style = 'low',  count = 1 },
    { label = 'Pizza This, Mirror Park',        coords = vector3(812.0, -752.99, 26.78),    style = 'low',  count = 1 },
    { label = 'Cat Cafe, Little Seoul',         coords = vector3(-581.06, -1066.22, 22.34), style = 'low',  count = 1 },
    { label = 'Diamond Casino drop-off',        coords = vector3(927.68, 49.65, 81.54),     style = 'high', count = 1 },
    { label = 'Four Dragons casino',            coords = vector3(380.05, 261.9, 93.06),     style = 'high', count = 1 },
    { label = 'Del Perro pier entrance',        coords = vector3(-1650.0, -1080.0, 13.0),   style = 'low',  count = 2 },
    { label = 'Vespucci Beach boardwalk (approximate)', coords = vector3(-1240.0, -1510.0, 4.3), style = 'low', count = 1 },
    { label = 'Vespucci Blvd at Magellan (approximate)', coords = vector3(-1150.0, -1420.0, 4.5), style = 'low', count = 1 },
    { label = 'Sandy Motel',                    coords = vector3(1628.05, 3787.72, 35.57),  style = 'low',  count = 1 },
    { label = 'Sandy Apartments',               coords = vector3(1538.91, 3537.04, 36.91),  style = 'low',  count = 1 },
    { label = 'Sandy illegal garage and gas',   coords = vector3(2015.01, 3775.77, 32.72),  style = 'low',  count = 1 },
    { label = 'Yellow Jack Inn',                coords = vector3(1985.0, 3053.0, 47.2),     style = 'low',  count = 1 },
    { label = 'Sandy outskirts trailers',       coords = vector3(2700.0, 3400.0, 55.0),     style = 'low',  count = 1 },
    { label = 'Stab City trailer park (approximate)', coords = vector3(60.0, 3700.0, 40.0), style = 'low', count = 2 },
    { label = 'Paleto main drag (approximate)', coords = vector3(-146.0, 6150.0, 31.0),     style = 'low',  count = 1 },
    { label = 'Hookies, Great Ocean Hwy (approximate)', coords = vector3(-2192.0, 4291.0, 49.0), style = 'low', count = 1 },
}

return Config
