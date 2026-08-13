--[[
    dps-hookers - Framework Bridge Loader
    Auto-detects QBCore or ESX and loads the appropriate bridge
]]

Bridge = {}
local context = IsDuplicityVersion() and 'server' or 'client'

-- Auto-detect framework if not set in config
-- Qbox (qbx_core) is checked FIRST: it has no GetCoreObject() export, so the
-- legacy qb bridge would throw on a Qbox box. qbx_core commonly runs alongside
-- a qb-core compatibility shim, so it must win the detection.
if not Config.Framework or Config.Framework == 'auto' then
    if GetResourceState('qbx_core') == 'started' then
        Config.Framework = 'qbx'
    elseif GetResourceState('qb-core') == 'started' then
        Config.Framework = 'qb'
    elseif GetResourceState('es_extended') == 'started' then
        Config.Framework = 'esx'
    else
        print('[^1dps-hookers^7] No supported framework detected!')
        Config.Framework = 'qb' -- Default fallback
    end
end

-- Load the correct bridge file
local bridgeFile = ('bridge/%s.lua'):format(Config.Framework)
local fileContent = LoadResourceFile(GetCurrentResourceName(), bridgeFile)

if fileContent then
    local chunk, err = load(fileContent, bridgeFile)
    if chunk then
        -- Wrap execution so a bridge fault (e.g. a missing export throwing on
        -- load) fails LOUDLY here instead of silently leaving Bridge.* as nil
        -- and nil-cascading through every downstream call.
        local ok, runErr = pcall(chunk)
        if ok then
            print(('[^5dps-hookers^7] Loaded ^2%s^7 bridge for %s'):format(Config.Framework:upper(), context))
        else
            print(('[^1dps-hookers^7] Bridge %s failed to initialize: %s'):format(bridgeFile, tostring(runErr)))
        end
    else
        print(('[^1dps-hookers^7] Failed to load bridge: %s'):format(err))
    end
else
    print(('[^1dps-hookers^7] Bridge file not found: %s'):format(bridgeFile))
end
