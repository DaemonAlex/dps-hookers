# DPS Hookers
![d18db8-17](https://github.com/user-attachments/assets/918a899a-b5a1-4794-bf73-44aa30ace36a)

**Adult RP system with intelligent police dispatch (18+ Only)**

Adapted from MH Hookers by MaDHouSe for DPS Development.

---

## What it is for

Adult servers want a red-light scene that has some risk in it. This script gives players a pimp at the Vanilla Unicorn and street girls outside the night spots. It also gives police a reason to patrol those streets: when a bystander NPC sees what is going on, a call can reach the police. Staff do not have to run any of it. It is for 18+ servers only, and it checks the character's age.

---

## Features

### Core Functionality
- **Pimp NPC** at Vanilla Unicorn strip club
- **Hooker spawning system** with randomized models
- **Vehicle-based interactions** with full animation sequences
- **Two service types**: Blowjob ($100) and Sex ($500)
- **Stress relief system** (default: jg-hud state bags; configurable to qb-hud/custom/none)
- **Age verification** (18+ characters only based on birthdate, re-checked server-side on every paid action)

### Street Corners
- **Street girls outside the night spots** - 19 corners in `Config.Corners`, from the Vanilla Unicorn and the casinos to Sandy Shores and Paleto
- **Night only** - they work from 21:00 to 05:00 game time. The pair outside the Vanilla Unicorn is there all day
- **Call-outs** - a girl calls out to players who walk past, with a spoken line and floating text
- **Pick-up** - talk to her with ox_target, or stop a car beside her, then press **E** as in the pimp flow
- **Never in the road** - each spot is moved to the pavement. A spot too close to the road or to a parked car is skipped
- **One map blip** at the Vanilla Unicorn

### Smart Police Dispatch AI
- **Witness-based detection** - Requires nearby NPCs to "see" the activity
- **Dynamic risk calculation** based on:
  - **Location** - Alleys/secluded areas are safer, downtown is riskier
  - **Time of day** - Night is safer, daytime increases risk
  - **Weather** - Rain/fog reduces visibility and risk
  - **Witness count** - More witnesses = higher chance of police
- **Delayed dispatch** - Secluded areas have 30-60s delay, simulating bystander reports
- **Configurable dispatch systems**: wasabi_mdt (default), ps-dispatch, cd_dispatch, qs-dispatch, or custom
- **5-minute cooldown** between police alerts per player

### Performance Optimizations (v2.2.0)
- **LOD-based threading** with ox_lib zones
- **Native result caching** (PlayerPedId, coords) at 100ms intervals
- **Distance-based cleanup** - Hooker NPCs auto-despawn if player drives too far
- **Entity state bags** for ownership tracking

### Modern Tech Stack
- **Multi-framework support** - Qbox (qbx_core), QBCore and ESX via Bridge abstraction
- **Auto-detection** - Automatically detects your framework on startup (qbx_core is detected first; it has no `GetCoreObject()` so it needs its own bridge)
- **ox_lib** context menus, progress circles, and notifications
- **ox_target** for NPC interactions
- **Locale system** with JSON translations
- **Clean, documented code** with LuaLS annotations

---

## On its own, and with other scripts

**On its own.** With a framework (Qbox on DelPerroSands), ox_lib and ox_target you get the pimp at the Vanilla Unicorn, the street corners, the car flow, the two paid services and the age check. The risk system still runs, but with no dispatch script no call is sent. The script sees that the dispatch resource is missing and switches police alerts off without errors.

**With a paid police computer (wasabi_mdt).** This is the default. When a witness NPC reports the player, a "disturbance" call from an anonymous caller appears on the MDT with the street name. In a quiet spot the call comes 30 to 60 seconds late, as if someone found the scene afterwards. Police get a reason to drive over and the player gets a reason to pick the spot with care. The script only sends a call through the wasabi_mdt `CreateDispatch` export. It reads and changes nothing else in the MDT.

**With another dispatch script (qs-dispatch, cd_dispatch, ps-dispatch).** Set `Config.Police.DispatchType` to the one you run. The call goes out as a suspicious activity alert with a map blip. qs-dispatch and cd_dispatch are paid scripts. ps-dispatch is free. Each one is called through a single export or event, and the call is skipped if it fails.

**With a paid HUD (jg-hud).** Each service lowers the player's stress by 15 to 25 points. With jg-hud the script lowers the `stress` state bag on the player, and the HUD shows the new value. It does not call any jg-hud code. Set `Config.StressSystem` to `'qb-hud'`, `'custom'` or `'none'` for other setups.

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
    DispatchType = 'wasabi_mdt',  -- 'wasabi_mdt', 'ps-dispatch', 'cd_dispatch', 'qs-dispatch', 'custom', 'none'

    -- Witness system
    RequireWitness = true,
    WitnessRadius = 40.0,

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
    Min = 15,
    Max = 25
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

Already configured for qs-dispatch. Just ensure it's installed and running.
### wasabi_mdt (Default)

Already configured for wasabi_mdt. Just ensure it's installed and running.

### QS-Dispatch

```lua
Config.Police.DispatchType = 'qs-dispatch'
```

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

- **qbx_core** OR **qb-core** OR **es_extended** - Framework (one required)
- **ox_lib** - Notifications, progress bars, locale, context menus, zones
- **ox_target** - NPC interactions
- **One of:** wasabi_mdt, ps-dispatch, cd_dispatch, qs-dispatch (optional). If none is installed the police system soft-detects the absence and no-ops cleanly.

> **Note:** oxmysql was previously listed but this resource performs no SQL. It was removed as a dependency in v2.3.1.

---

## File Structure

```
dps-hookers/
├── fxmanifest.lua          # Resource manifest
├── config.lua              # All configuration settings
├── bridge/
│   ├── init.lua            # Framework auto-detection
│   ├── qbx.lua             # Qbox (qbx_core) bridge
│   ├── qb.lua              # QBCore bridge
│   └── esx.lua             # ESX bridge
├── locales/
│   └── en.json             # English translations
├── client/
│   ├── main.lua            # Client-side logic (optimized)
│   └── corners.lua         # Street corners
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
- **Frameworks:** QBCore Team, ESX Team
- **Libraries:** Overextended (ox_lib, ox_target)

---

## Support

For issues:

1. Check your server console for errors
2. Verify all dependencies are installed and up to date
3. Ensure your server is running a supported framework (Qbox / QB-Core / ESX)
4. Check config.lua settings match your server setup

---

## License

GPL-3.0 - Maintained from original MH Hookers by MaDHouSe79.

**18+ Content Warning:** This resource contains adult content and should only be used on servers with proper age verification and player consent systems in place.

---

## Future Features (Roadmap)

Planned features for future releases. **None of the items below are implemented yet** - they are aspirational and their version labels are tentative.

### Planned - Health & Consequences
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

### v3.2.0 - AI Integration (ai-npcs)
- [ ] **AI-Powered Hookers** - Dynamic conversations with memory
  - Remember repeat customers, preferences
  - Context-aware dialogue (knows your gang, cash, reputation)
  - ElevenLabs voice synthesis for immersion
- [ ] **Trust/Reputation System** - Build relationships over time
  - Stranger: Basic services only
  - Acquaintance: Discounts, small talk
  - Trusted: Intel on safe spots, police patterns
  - Inner Circle: Exclusive services, pimp introductions
- [ ] **AI Pimp NPC** - Intelligent quest giver
  - Offers missions (deliveries, collections, recruitment)
  - Shares intel about police heat, rival operations
  - Remembers your history, adjusts dialogue
- [ ] **Hooker Personalities** - Each worker has unique traits
  - Some chatty, some quiet
  - Preferences and turn-offs
  - Backstories that unfold with trust

### Ideas Backlog
- [ ] **Wandering Hookers** - NPCs that walk the streets at night, can be flagged down
- [ ] Drug-fueled services (higher risk, more stress relief)
- [ ] Robbery chance (hooker steals your money)
- [ ] Phone ordering system (qs-smartphone integration)
- [ ] Reviews system (reputation affects prices)
- [ ] Multiplayer services (requires 2 players)
- [ ] Hotel/motel room rentals for privacy bonus
- [ ] Blackmail system (hookers can extort repeat customers)

---

## Changelog

### Recent changes

- **12 November 2026.** README: what it is for, how it works alone and with paid scripts, other DPS scripts. The README now shows wasabi_mdt as the default dispatch, to match `config.lua`.
- **30 October 2026.** Street corners: two fixes to the pavement check, which read the game's position results in the wrong shape and threw a client error.
- **29 October 2026.** Street corners added: girls outside 19 night spots, call-outs to people who walk past, a pavement rule so nobody stands in the road, night hours of 21:00 to 05:00, and one blip at the Vanilla Unicorn.

### v2.3.1 (Qbox + Security Fix Pass)
- **Added Qbox (qbx_core) bridge** (`bridge/qbx.lua`) using discrete exports - qbx_core has no `GetCoreObject()`, which made the qb bridge throw and killed the resource on a pure Qbox box. init.lua now detects `qbx_core` first; bridge load is pcall-wrapped so a bridge fault fails loudly instead of nil-cascading.
- **Risk engine moved client-side** - police risk (peds/clock/weather/street name) is now computed on the client where those natives actually work, then validated + rolled server-side. Previously these client-only natives ran on the server and silently returned 0/blank.
- **Server-authoritative police roll** - coords are cross-checked against the player's real server position; witness count and risk are clamped; the roll itself runs on the server.
- **Age gate re-checked server-side** in `server:pay` and `server:policeRoll` (previously only at join).
- **Dispatch soft-detection** - if the configured dispatch resource isn't running, the system falls back to a clean no-op instead of hard-erroring (qs-dispatch path is now pcall-guarded and resource-checked).
- **Hooker is now a LOCAL ped** so a mid-service client crash can't orphan a networked ped on the server.
- **`server:pay` now requires an active-hooker state** (set only after the signal -> enter-vehicle flow) to block direct-trigger farming.
- Removed dead `oxmysql` dependency (no SQL is performed).
- Reconciled README numbers (StressRelief 15/25, WitnessRadius 40.0) and framework wording (Qbox/QBCore/ESX).

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

---

## Author

Made by [DaemonAlex](https://github.com/DaemonAlex) for DelPerroSands.

This is an adaptation of MH Hookers by MaDHouSe79. See Credits above.

## Other DPS scripts

All of these are made for DelPerroSands and run together on one Qbox server. Each one works on
its own. The ones marked "pairs with" do more when both are running.

| Script | What it does |
|---|---|
| [dps-inventory](https://github.com/DaemonAlex/dps-inventory) | The inventory: ox_inventory with equipment slots, backpacks, armour plates and a self status panel, in the DelPerroSands colours. |
| [dps-medical](https://github.com/DaemonAlex/dps-medical) | Patient records, illness and diagnostic tests. A companion to wasabi_ambulance. Pairs with dps-inventory: symptoms and diagnoses show on the status panel. |
| [dps-insurance](https://github.com/DaemonAlex/dps-insurance) | Ties m-Insurance into the MDT, impound, hospital and medical chart. Pairs with dps-medical. |
| [dps-studio](https://github.com/DaemonAlex/dps-studio) | Build rooms, doors and portals in game from one panel (`/studio`), with owners and managers so staff do not have to support them. |
| [dps-shops](https://github.com/DaemonAlex/dps-shops) | Shop clerks who greet and react to a robbery, then player-owned shops. |
| [dps-fleet](https://github.com/DaemonAlex/dps-fleet) | Vehicle browser and workshop on one panel: extras, liveries and mods for emergency vehicles. |
| [dps-parking](https://github.com/DaemonAlex/dps-parking) | Parking with valet, impound, violations and reserved spots. |
| [dps-vehiclepersistence](https://github.com/DaemonAlex/dps-vehiclepersistence) | Vehicles stay where they were parked. Pairs with dps-parking. |
| [dps-towjob](https://github.com/DaemonAlex/dps-towjob) | Queue-based tow job with jg-mechanic integration. |
| [dps-services](https://github.com/DaemonAlex/dps-services) | Request a tow and follow it live on the lb-phone and lb-tablet. Pairs with dps-towjob. |
| [dps-autoshops](https://github.com/DaemonAlex/dps-autoshops) | Self-service repair shops when no mechanic is on duty. |
| [dps-cityworker](https://github.com/DaemonAlex/dps-cityworker) | City infrastructure job and career. |
| [dps-ainpcs](https://github.com/DaemonAlex/dps-ainpcs) | NPCs you can talk to, with trust, quests and intel. |
| [dps-badpeds](https://github.com/DaemonAlex/dps-badpeds) | Police interaction with NPCs: stops, arrests, intel and jail records. |
| [dps-gangwars](https://github.com/DaemonAlex/dps-gangwars) | Ambient gang NPCs, territory population and war reinforcements. |
| [dps-rotations](https://github.com/DaemonAlex/dps-rotations) | Moves dealers, harvests and other spots on a fixed schedule. |
| [dps-trains](https://github.com/DaemonAlex/dps-trains) | The train system. Pairs with dps-trains-stock, dps-traintools and dps-transitapp. |
| [dps-transitapp](https://github.com/DaemonAlex/dps-transitapp) | Live train arrival boards on the lb-phone. |
| [dps-faceplant](https://github.com/DaemonAlex/dps-faceplant) | City help, reports and staff tools on the lb-phone and lb-tablet. |
| [dps-chat](https://github.com/DaemonAlex/dps-chat) | A command box for voice-only servers. No chat feed. |
| [dps-filmmode](https://github.com/DaemonAlex/dps-filmmode) | One key hides every HUD layer and gives a smooth free camera for recording. |
