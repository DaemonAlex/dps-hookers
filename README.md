# DPS Hookers

**Adult RP system with intelligent police dispatch (18+ Only)**

Adapted from MH Hookers by MaDHouSe for DPS Development.

---

## Features

### Core Functionality
- **Pimp NPC** at Vanilla Unicorn strip club
- **Hooker spawning system** with randomized models
- **Vehicle-based interactions** with full animation sequences
- **Two service types**: Blowjob ($100) and Sex ($500)
- **Stress relief system** integrated with QB-Core HUD
- **Age verification** (18+ characters only based on birthdate)

### Smart Police Dispatch AI
- **Witness-based detection** - Requires nearby NPCs to "see" the activity
- **Dynamic risk calculation** based on:
  - **Location** - Alleys/secluded areas are safer, downtown is riskier
  - **Time of day** - Night is safer, daytime increases risk
  - **Weather** - Rain/fog reduces visibility and risk
  - **Witness count** - More witnesses = higher chance of police
- **Delayed dispatch** - Secluded areas have 30-60s delay, simulating bystander reports
- **Configurable dispatch systems**: ps-dispatch, cd_dispatch, qs-dispatch, or custom
- **5-minute cooldown** between police alerts per player

### Performance Optimizations (v2.2.0)
- **LOD-based threading** with ox_lib zones
- **Native result caching** (PlayerPedId, coords) at 100ms intervals
- **Distance-based cleanup** - Hooker NPCs auto-despawn if player drives too far
- **Entity state bags** for ownership tracking

### Modern Tech Stack
- **QB-Core framework** integration (qb-core)
- **ox_lib** context menus, progress circles, and notifications
- **ox_target** for NPC interactions
- **Locale system** with JSON translations
- **Clean, documented code** with LuaLS annotations

---

## Installation

1. **Copy** `dps-hookers` folder to your server's `resources` directory

2. **Add to server.cfg**:
   ```cfg
   ensure dps-hookers
   ```

3. **Configure** `config.lua` (see Configuration section below)

4. **Restart server** or `ensure dps-hookers`

---

## Configuration

### Police Dispatch Settings

Located in `config.lua` - Police section:

```lua
Config.Police = {
    Enabled = true,
    DispatchType = 'qs-dispatch',  -- 'ps-dispatch', 'cd_dispatch', 'qs-dispatch', 'custom', 'none'

    -- Witness system
    RequireWitness = true,
    WitnessRadius = 30.0,

    -- Delayed dispatch (simulates bystander finding scene)
    DelayedDispatch = {
        enabled = true,
        secludedDelay = {min = 30000, max = 60000},  -- 30-60s in secluded areas
        normalDelay = {min = 5000, max = 15000},     -- 5-15s normally
    },

    BaseChance = 15,  -- Base 15% police chance

    -- Location modifiers
    LocationRisk = {
        Busy = { modifier = 25 },      -- +25% in busy downtown areas
        Secluded = { modifier = -20 }, -- -20% in alleys/isolated areas
        Industrial = { modifier = -12 }, -- -12% in industrial zones
        StripClub = { modifier = -10 }, -- -10% near strip club
    },

    -- Time modifiers
    TimeRisk = {
        Day = { modifier = 10 },   -- +10% during day (06:00-18:00)
        Night = { modifier = -8 }, -- -8% at night (22:00-06:00)
    },

    -- Weather modifier
    Weather = {
        badWeather = { modifier = -10 },  -- -10% in rain/fog/smog
    },

    Cooldown = 300,  -- 5 minutes between alerts per player
}
```

### Price & Service Settings

```lua
-- Adjust for your server's economy
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
    Signal = { label = 'E', key = 38 },           -- Signal hooker / Open menu
    Blowjob = { label = 'ARROW UP', key = 172 },  -- Request blowjob (legacy)
    Sex = { label = 'ARROW DOWN', key = 173 },    -- Request sex (legacy)
    Dismiss = { label = 'ARROW LEFT', key = 174 } -- Send hooker away (legacy)
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
6. **When stopped**, press **E** to open the service menu:
   - Blowjob ($100)
   - Full Service ($500)
   - Send Away
7. **Watch for police!** - Depending on location/time/witnesses, police may be called

### Police Dispatch Intelligence

The script calculates risk dynamically with witness detection:

**Risk Calculation Examples:**

| Location | Time | Weather | Witnesses | Total Risk |
|----------|------|---------|-----------|------------|
| Secluded alley | Night | Rain | 0 | **0%** - No dispatch possible |
| Industrial docks | Night | Clear | 1 | **~0%** - Very safe |
| Strip club area | Evening | Clear | 2 | **~10%** - Low risk |
| Downtown | Day | Clear | 5+ | **~75%** - Very risky |

**Best Strategy:** Find a secluded spot at night during bad weather with no pedestrians nearby.

---

## Police Dispatch Integration

### QS-Dispatch (Default)

Already configured for qs-dispatch. Just ensure it's installed and running.

### PS-Dispatch

```lua
Config.Police.DispatchType = 'ps-dispatch'
```

### CD-Dispatch

```lua
Config.Police.DispatchType = 'cd_dispatch'
```

### Custom System

```lua
Config.Police.DispatchType = 'custom'
```

Then edit `server/main.lua` to customize your dispatch event.

---

## Age Verification

The script checks character birthdate against server date (with -4 year offset as per QB standard).

**Supported formats:**
- `YYYY-MM-DD` (e.g., 2000-05-15)
- `DD/MM/YYYY` (e.g., 15/05/2000)

**Required:** Character must be 18+ based on their `PlayerData.charinfo.birthdate`

To disable:
```lua
Config.AgeVerification = false
```

---

## Dependencies

- **qb-core** - QB-Core framework
- **ox_lib** - Notifications, progress bars, locale, context menus, zones
- **ox_target** - NPC interactions
- **oxmysql** - Database
- **One of:** ps-dispatch, cd_dispatch, qs-dispatch (optional, for police alerts)

---

## File Structure

```
dps-hookers/
├── fxmanifest.lua          # Resource manifest
├── config.lua              # All configuration settings
├── locales/
│   └── en.json             # English translations
├── client/
│   └── main.lua            # Client-side logic (optimized)
├── server/
│   └── main.lua            # Server-side logic
└── README.md               # This file
```

---

## Performance

- **LOD-based sleep times** - 0ms when active, up to 2000ms when idle
- **Native caching** - PlayerPedId, coords cached every 100ms
- **Distance-based cleanup** - Abandoned hookers auto-despawn at 150m
- **Entity state bags** - Proper ownership tracking
- **Automatic model unloading** - Memory efficient

### OneSync Requirements

This script uses **Entity State Bags** for hooker ownership tracking. Ensure your server has:

```cfg
# server.cfg
set onesync on
set onesync_population true
```

State bags prevent "network floods" and ensure proper entity sync across all clients.

---

## Debug Mode

Enable in config:
```lua
Config.Debug = true
```

Server console shows police roll results:
```
[DPS Hookers] Police roll for PlayerName: 23/100 (Risk: 45%)
[DPS Hookers] Dispatch delayed by 45000ms for PlayerName
[DPS Hookers] Police dispatched for PlayerName at Mirror Park
```

---

## Credits

- **Original Script:** MH Hookers by MaDHouSe79
- **Adaptation:** DPS Development
- **Framework:** QB-Core (qb-core)
- **Libraries:** Overextended (ox_lib, ox_target)

---

## Support

For issues:

1. Check your server console for errors
2. Verify all dependencies are installed and up to date
3. Ensure your server is running QB-Core framework
4. Check config.lua settings match your server setup

---

## License

GPL-3.0 - Maintained from original MH Hookers by MaDHouSe79.

**18+ Content Warning:** This resource contains adult content and should only be used on servers with proper age verification and player consent systems in place.

---

## Future Features (Roadmap)

Planned features for future releases:

### v2.3.0 - Health & Consequences
- [ ] **STD System** - Chance to contract diseases from services
  - Configurable infection chance per service type
  - Requires treatment at wasabi_ambulance/hospital
  - Symptoms: health drain, stamina reduction, visual effects
  - Treatment cost configurable
- [ ] **Condom Item** - Reduces STD chance (qs-inventory integration)

### v2.4.0 - Expanded Services
- [ ] **Multiple Hooker Types** - Different price tiers and models
- [ ] **VIP Services** - Premium options with better stress relief
- [ ] **Repeat Customer Discounts** - Loyalty system

### v2.5.0 - Immersion
- [ ] **Police Sting Operations** - Undercover cops posing as hookers
- [ ] **Pimp Missions** - Side jobs from the pimp NPC
- [ ] **Hooker Preferences** - Some refuse certain services

### v3.0.0 - Gang Integration (rcore_gangs)
- [ ] **Gang Territory Bonuses** - Operating in your gang's turf
  - Lower police risk in controlled territory
  - Gang members provide "lookout" witness reduction
  - Revenue split with gang treasury
- [ ] **Territory Prostitution Rights** - Gangs control who works where
  - `exports['rcore_gangs']:GetZoneAtPosition()` integration
  - Operating in rival territory = high risk + gang retaliation
  - Turf wars can include prostitution revenue
- [ ] **Gang Loyalty from Pimping** - Running hookers builds rep
  - `rcore_gangs:server:increase_loyalty` on successful services
  - Higher rank = more workers allowed
  - Gang bosses can assign pimping rights

### v3.1.0 - Player Pimp Business
- [ ] **Player-Run Pimp Operations** - Run it like a criminal enterprise
  - Recruit NPC hookers to work for you
  - Set prices and collect percentage of earnings
  - Manage multiple workers across gang territory
- [ ] **Police Heat System** - The bigger your operation, the more attention
  - Raids on known pimp locations (wasabi_police integration)
  - Undercover investigations
  - Asset seizure if caught
- [ ] **Worker Management** - Keep your workers happy or they leave/snitch
  - Pay protection money to gang
  - Provide safe locations
  - Handle customer complaints
- [ ] **Money Laundering** - Clean dirty money through gang businesses

### Ideas Backlog
- [ ] **Wandering Hookers** - NPCs that walk the streets at night, can be flagged down
- [ ] Drug-fueled services (higher risk, more stress relief)
- [ ] Robbery chance (hooker steals your money)
- [ ] Phone ordering system (qs-smartphone integration)
- [ ] Reviews system (reputation affects prices)
- [ ] Multiplayer services (requires 2 players)
- [ ] Hotel/motel room rentals for privacy bonus

---

## Changelog

### v2.2.0 (Performance Update)
- LOD-based threading with ox_lib zones
- Native result caching (100ms interval)
- Witness NPC detection system
- Delayed dispatch for secluded areas
- Entity state bags for ownership
- ox_lib context menu for services
- Distance-based hooker cleanup
- Balance tuning for dispatch AI

### v2.1.0 (Security Update)
- Server-side payment validation
- Active service tracking (prevents double-charge)
- Configurable stress system
- Debug mode toggle
- Improved age verification (multiple date formats)

### v2.0.0 (DPS Adaptation)
- Converted to QB-Core + ox_lib
- Integrated ox_lib progress circles
- Added intelligent police dispatch system
- Location/time/weather risk calculation
- ox_target integration for pimp NPC
- Locale system with JSON translations

### v1.0.0 (Original)
- Initial release by MaDHouSe79
- Adaptation and rewrites by DaemonAlex
