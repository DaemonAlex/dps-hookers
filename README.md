# DSRP Hookers

**Adult RP system with intelligent police dispatch (18+ Only)**

Adapted from MH Hookers by MaDHouSe for DelPerro Sands RP.

---

## Features

### Core Functionality
- **Pimp NPC** at Vanilla Unicorn strip club
- **Hooker spawning system** with randomized models
- **Vehicle-based interactions** with full animation sequences
- **Two service types**: Blowjob ($100) and Sex ($500)
- **Stress relief system** integrated with QBox HUD
- **Age verification** (18+ characters only based on birthdate)

### Smart Police Dispatch AI
- **Dynamic risk calculation** based on:
  - **Location** - Alleys/secluded areas are safer, downtown is riskier
  - **Time of day** - Night is safer, daytime increases risk
  - **Weather** - Rain/fog reduces visibility and risk
  - **Population density** - Fewer witnesses = lower chance of police
- **Configurable dispatch systems**: ps-dispatch, cd_dispatch, qs-dispatch, or custom
- **5-minute cooldown** between police alerts per player
- **Risk ranges**: Base 15% chance with modifiers from -15% to +25%

### Modern Tech Stack
- **QBox framework** integration (qbx_core)
- **ox_lib** progress circles with animations
- **ox_target** for NPC interactions
- **ox_inventory** for payments
- **Locale system** with JSON translations
- **Clean, documented code** with LuaLS annotations

---

## Installation

1. **Copy** `dsrp-hookers` folder to your server's `resources` directory

2. **Add to server.cfg**:
   ```cfg
   ensure dsrp-hookers
   ```

3. **Configure** `config.lua` (see Configuration section below)

4. **Restart server** or `ensure dsrp-hookers`

---

## Configuration

### Police Dispatch Settings

Located in `config.lua` - Police section:

```lua
Config.Police = {
    Enabled = true,
    DispatchType = 'ps-dispatch',  -- 'ps-dispatch', 'cd_dispatch', 'qs-dispatch', 'custom', 'none'
    BaseChance = 15,               -- Base 15% police chance

    -- Location modifiers
    LocationRisk = {
        Busy = {
            enabled = true,
            modifier = 25,  -- +25% in busy downtown areas
        },
        Secluded = {
            enabled = true,
            modifier = -15,  -- -15% in alleys/isolated areas
        },
        StripClub = {
            enabled = true,
            modifier = -10,  -- -10% near strip club
        },
        -- ...more zones
    },

    -- Time modifiers
    TimeRisk = {
        Day = { modifier = 10 },     -- +10% during day (06:00-18:00)
        Night = { modifier = -8 },   -- -8% at night (22:00-06:00)
    },

    Cooldown = 300,  -- 5 minutes between alerts per player
}
```

### Price & Service Settings

```lua
Config.Prices = {
    Blowjob = 100,
    Sex = 500
}

Config.StressRelief = {
    Min = 2,
    Max = 4
}

Config.Animations = {
    BlowjobDuration = 30000,  -- 30 seconds
    SexDuration = 30000
}
```

### NPC Locations

```lua
-- Hooker spawn point (strip club parking lot)
Config.HookerSpawn = vector4(136.2074, -1278.8458, 29.3648, 299.4893)

-- Pimp location (strip club entrance)
Config.PimpLocation = vector4(117.3872, -1305.0110, 29.2328, 217.0572)
```

### Controls

```lua
Config.Controls = {
    Signal = { label = 'E', key = 38 },           -- Signal hooker to enter vehicle
    Blowjob = { label = 'ARROW UP', key = 172 },  -- Request blowjob
    Sex = { label = 'ARROW DOWN', key = 173 },    -- Request sex
    Dismiss = { label = 'ARROW LEFT', key = 174 } -- Send hooker away
}
```

---

## How It Works

### For Players

1. **Visit the pimp** at Vanilla Unicorn strip club entrance
2. **Interact** with ox_target to order a hooker
3. **Drive to the marked location** (hooker spawns at strip club parking)
4. **Press E** while in your vehicle to signal the hooker
5. **Wait for her to enter** your passenger seat
6. **When stopped**, press arrow keys:
   - **↑** Arrow Up = Blowjob ($100)
   - **↓** Arrow Down = Sex ($500)
   - **←→** Arrow Left/Right = Send her away
7. **Watch for police!** - Depending on location/time, police may be called

### Police Dispatch Intelligence

The script calculates risk dynamically:

**Example Scenarios:**

| Location | Time | Weather | Total Risk | Notes |
|----------|------|---------|------------|-------|
| Dark alley | Night (23:00) | Rain | **~5%** | Very safe - isolated + night + weather |
| Downtown | Day (14:00) | Clear | **~50%** | Very risky - busy area + daytime |
| Strip club area | Evening (20:00) | Clear | **~5%** | Safe - expected activity location |
| Residential | Morning (08:00) | Clear | **~30%** | Moderate - some witnesses around |

**Formula:**
```
Base 15% + Location Modifier + Time Modifier + Weather Modifier = Total Risk
```

---

## Police Dispatch Integration

### PS-Dispatch (Default)

Already configured. Just ensure ps-dispatch is installed and running.

### CD-Dispatch

Change in config.lua:
```lua
Config.Police.DispatchType = 'cd_dispatch'
```

### QS-Dispatch

Change in config.lua:
```lua
Config.Police.DispatchType = 'qs-dispatch'
```

### Custom System

```lua
Config.Police.DispatchType = 'custom'
```

Then edit `server/main.lua` line 236-245 to customize your dispatch event.

---

## Age Verification

The script checks character birthdate against server date (with -4 year offset as per QB standard).

**Required:** Character must be 18+ based on their `PlayerData.charinfo.birthdate`

Players under 18 will see an error and cannot access the resource.

To disable:
```lua
Config.AgeVerification = false
```

---

## Dependencies

- **qbx_core** - QBox framework
- **ox_lib** - Notifications, progress bars, locale
- **ox_target** - NPC interactions
- **ox_inventory** - Payment handling
- **oxmysql** - Database (if needed for future features)
- **One of:** ps-dispatch, cd_dispatch, qs-dispatch (optional, for police alerts)

---

## File Structure

```
dsrp-hookers/
├── fxmanifest.lua          # Resource manifest
├── config.lua              # All configuration settings
├── locales/
│   └── en.json            # English translations
├── client/
│   └── main.lua           # Client-side logic
├── server/
│   └── main.lua           # Server-side logic
└── README.md              # This file
```

---

## Localization

Edit `locales/en.json` to change messages.

To add a new language:
1. Copy `locales/en.json` to `locales/es.json` (or your language code)
2. Translate all strings
3. Players' game language will auto-select the locale

---

## Debug Mode

Server console shows police roll results:

```
[DSRP Hookers] Police roll for PlayerName: 23/100 (Risk: 45%)
[DSRP Hookers] Police dispatched for PlayerName at Mirror Park (Risk was 45%)
```

To disable, comment out print statements in `server/main.lua` lines 187-192 and 255-259.

---

## Performance

- **Minimal resource usage** - Only active when hooker is spawned
- **Automatic cleanup** - NPCs deleted on resource stop
- **Optimized loops** - Sleep times dynamically adjusted
- **Memory efficient** - Models unloaded after use

---

## Credits

- **Original Script:** MH Hookers by MaDHouSe79
- **Adaptation:** DelPerro Sands RP Development Team
- **Framework:** QBox (qbx_core)
- **Libraries:** Overextended (ox_lib, ox_target, ox_inventory)

---

## Support

This is a custom adaptation for DelPerro Sands RP. For issues:

1. Check your server console for errors
2. Verify all dependencies are installed and up to date
3. Ensure your server is running QBox framework
4. Check config.lua settings match your server setup

---

## License

This is an adaptation of MH Hookers by MaDHouSe79, modified for DSRP's QBox environment.

**18+ Content Warning:** This resource contains adult content and should only be used on servers with proper age verification and player consent systems in place.

---

## Changelog

### v2.0.0 (DSRP Adaptation)
- ✅ Converted from QB/ESX to QBox-only
- ✅ Integrated ox_lib progress circles
- ✅ Added intelligent police dispatch system
- ✅ Location-based risk calculation
- ✅ Time-of-day risk modifiers
- ✅ Weather-based risk adjustment
- ✅ Converted to ox_lib locale system
- ✅ ox_target integration for pimp NPC
- ✅ Improved code organization and documentation
- ✅ Added LuaLS annotations
- ✅ Removed update.lua and legacy core files
- ✅ Unified config system

### v1.0.0 (Original)
- Initial release by MaDHouSe79