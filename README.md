# APS Racer

Top-down racing prototype built in Godot 4.7.2 with a custom four-wheel vehicle simulation.

## Overview

APS Racer combines a custom handling model, three selectable physical course layouts, skin-specific production vehicle art, textured/prop-driven environments, automatic/manual transmission modes, a compact race HUD, mobile controls, Handling Lab, persistent lap records, ghost replay, and an AI opponent in a complete three-lap event.

### Physics

- 120 Hz custom vehicle simulation substep
- Four tyre contact patches
- Finite tyre grip budget / combined longitudinal and lateral grip
- Longitudinal weight transfer
- Slip-angle telemetry
- Speed-sensitive steering
- Aerodynamic drag and rolling resistance
- Handbrake rear-grip reduction
- Asphalt and grass grip
- Barrier collision response
- Visible impact-speed telemetry
- Progressive grip-limit meter and controller rumble warning
- Automatic or six-speed manual transmission mode
- Useful reverse drive with a deliberate speed limiter

### Cars

Press 1/2/3, D-pad left/right, or the CAR touch button to switch physics classes:

1. RWD Sport
2. FWD Hatch
3. AWD Rally

The visible vehicle is skin-specific while the underlying physics class remains unchanged.

**Red Dirt**
- RWD Sport -> Desert Prerunner
- FWD Hatch -> Baja Compact
- AWD Rally -> Monster 4x4

**Brisbane Neon Rain**
- RWD Sport -> Neon GT Coupe
- FWD Hatch -> Neon Hot Hatch
- AWD Rally -> XC90 P2 Nightrunner

The six runtime composites are true top-down sprites with transparent backgrounds. Procedural cars remain only as a fallback if an art asset is missing.

Transmission mode is independent of the selected car. **M** (keyboard) or **Y** (gamepad) switches AUTO/MANUAL. In manual mode use **Q/E** or the shoulder buttons to shift down/up.

### Courses

Press **C** or tap the course button to switch layouts.

**ROUND**
- rounded high-speed circuit
- broad straights and sweeping corners

**FIGURE 8**
- intersecting same-level figure-eight circuit
- tighter lobes and crossover
- independent road ribbon, barrier collision geometry, grid, checkpoints and AI racing line

**AIRFIELD**
- grippy tarmac circuit around an airfield infield
- long runway straights and fast end turns
- aircraft, hangar, tower, runway markings and apron treatment
- fixed high-grip tarmac profile independent of visual skin

All courses support both visual skins. Course choice does not change the selected car or handling setup.

- Theme-selectable surface grip profile on ROUND / FIGURE 8
- Dynamic drying racing line on wet Brisbane Neon Rain surfaces
- Braking/slalom markers rendered as environment-appropriate props
- Skid marks
- Optional dust / rain / spray visual effects
- Speed-dependent camera zoom and look-ahead

### Visual skins

Press **G** or tap **SKIN** to switch the presentation without changing the track geometry or race logic.

**Red Dirt**
- Broken Hill / Silverton influence
- Desert Prerunner / Baja Compact / Monster 4x4 vehicle family
- packed red-earth and loose-dirt texture assets
- tyre/rut treatment plus scrub, rocks, shed, signage and barrier props
- dust VFX assets
- rugged warm UI treatment

**Brisbane Neon Rain**
- Brisbane at about 02:00
- wet-road weather model with rain presentation
- Neon GT / Hot Hatch / XC90 P2 Nightrunner vehicle family
- wet-asphalt, puddle, reflection and lane-marking assets
- neon barriers, urban props and road furniture
- wet spray/splash VFX assets
- dynamic traffic-dried racing line that gains grip as it develops
- neon cyan/magenta edges and reflections
- dark translucent cyberpunk UI

Press **V** or use the **FX** touch control to hide rain, dust and tyre-weather effects without changing the underlying surface physics.

Skin definitions live in `themes.json`. Rendering is isolated in `visual_renderer.gd`; physics remains in `vehicle_sim.gd`, and track geometry/collision remains in `track_model.gd`. A new skin should therefore be data plus optional renderer rules rather than a rewrite of game logic.

### Race system

The current event is a three-lap race against one AI rival.

- 3.25 second start countdown
- ordered checkpoints with direction validation
- four timed sectors per lap
- current lap, last lap, best lap and sector timing
- P1/P2 live position
- persistent best-lap records per visual skin and car
- best-lap ghost recording at 30 Hz
- translucent ghost playback on subsequent laps/races
- first AI rival using the track's racing-line data
- player/rival contact response
- finish state and total race time
- RESET / R restarts the entire event

Race records are stored in `user://aps_racer_race_records.json`. The record/ghost key includes the active course, visual skin and selected car, so each course/skin/car combination retains independent records.

The AI and the player use the same track checkpoint rules. The permanent regression suite requires the rival to finish three laps on the lower-grip Red Dirt surface profile.

### Handling Lab

Press **T** or **F1**, or tap **TUNE**, to open the in-game Handling Lab.

The panel applies changes live and exposes 21 vehicle parameters, including mass, yaw inertia, wheelbase, track width, CG height, weight distribution, drivetrain split, engine/brake forces, tyre grip, corner stiffness, yaw damping, drag, steering locks/rate and handbrake behaviour.

Named tunes are persisted to `user://aps_racer_handling_presets.json` and can be saved, loaded and deleted in-game.

**RESET TO BAKED** restores the current car from `vehicle_presets.json`.

**BAKE CURRENT** writes the current setup back into the selected car slot in `vehicle_presets.json` when running from the Godot development/editor build. Exported builds are read-only, so they save a bake candidate and copy the values instead.

The intended development loop is:

    drive -> tune -> save variants -> compare -> bake winner -> keep building

### Controls

Keyboard:
- W / Up: throttle
- S / Down: brake / reverse at low speed
- A/D or Left/Right: steering
- Space: handbrake
- R: reset
- 1/2/3: select car
- G: switch visual skin
- C: switch ROUND / FIGURE 8 / AIRFIELD course
- M: toggle automatic/manual transmission
- Q / E: shift down / up in manual mode
- V: toggle weather/dirt visual effects
- H: toggle telemetry drawer
- T / F1: Handling Lab

Gamepad:
- Left stick: steering
- Right trigger or A: throttle
- Left trigger or B: brake
- X: handbrake
- Y: toggle automatic/manual transmission
- Left/right shoulder: shift down/up in manual mode
- Back/View: toggle weather/dirt visual effects
- D-pad left/right: change car
- Grip-limit rumble increases as available tyre grip is exhausted

Touch:
- Left/right steering
- GO
- BRAKE
- HANDBRAKE
- SKIN
- ROUND / FIG 8 / AIR course selector
- AUTO / M1-M6 transmission control
- GEAR - / GEAR + in manual mode
- FX ON / FX OFF
- DATA
- TUNE
- CAR
- RESET

## Automated regression baselines

Run:

    godot --headless --path . --script res://handling_tests.gd
    godot --headless --path . --script res://race_tests.gd

The normal build script runs both suites automatically.

Handling baseline:

- RWD Sport: 0-100 km/h 5.53 s; 100-0 km/h 33.3 m; sustained cornering 1.59 g
- FWD Hatch: 0-100 km/h 5.83 s; 100-0 km/h 30.5 m; sustained cornering 1.57 g
- AWD Rally: 0-100 km/h 5.44 s; 100-0 km/h 34.8 m; sustained cornering 1.64 g
- Reverse reaches about 45 km/h
- Manual first gear limits around 58 km/h; second gear around 92 km/h

The numbers are regression baselines, not final realism targets.

Race baseline:

- ordered and directional checkpoint validation
- three-lap event completion
- sector timing and best-lap retention
- ghost capture/playback
- wet racing-line grip rises measurably under traffic
- AI completes three Red Dirt ROUND laps in about 39 seconds while remaining predominantly on-track
- AI completes three Red Dirt FIGURE 8 laps in about 49 seconds while remaining predominantly on-track
- AI completes three AIRFIELD laps in about 50 seconds while remaining predominantly on-track

## Build

PowerShell:

    .\tools\build.ps1

The build script validates production art, runs handling/race tests, then exports all supported targets:

- Web: builds/web/index.html
- Windows: builds/windows/APSRacer.exe
- Android ARM64 debug APK: builds/android/APSRacer-debug.apk
- Linux x86_64 / Arch / Steam Deck: builds/linux/APSRacer.x86_64
- Portable Linux archive: builds/linux/APSRacer-Linux-x86_64.tar.gz

Use -WebOnly, -WindowsOnly, -AndroidOnly, -LinuxOnly, or -SkipTests when appropriate.

The Web export has been smoke-tested in Chrome with WebGL 2 and the Compatibility renderer. The Android APK is zip-aligned, debug-signed, and targets Android 16 / API 36. The Linux build is a standard x86_64 ELF and has been smoke-tested under Linux; the tarball preserves executable permissions and includes a Steam Deck launcher/instructions.

### Web memory stability

The Web presentation path is designed to remain bounded during long sessions:

- static world geometry is retained in `static_world_layer.gd` and only redrawn when the active skin changes
- weather is retained in `weather_layer.gd` and animated by transform rather than rebuilding particles/lines every frame
- track/racing-line geometry is cached
- AI ghost recording is disabled
- player ghost recording is hard-capped at 5,400 samples / 180 seconds
- vehicle and skin textures are cached and reused rather than recreated each frame

## Platform strategy

Primary targets:

- Windows development/reference build
- Linux x86_64, including Arch Linux and Steam Deck / SteamOS
- Android native APK
- Web browser build

The project uses GDScript and Godot's Compatibility renderer so desktop Linux, Windows, Web and Android remain first-class targets.

## Architecture

- `vehicle_sim.gd`: vehicle dynamics and tunable parameters
- `vehicle_presets.json`: baked car setups
- `track_model.gd`: selectable ROUND / FIGURE 8 geometry, barriers, surface queries, grids, race gates and racing lines
- `race_system.gd`: countdown, checkpoints, sectors, laps, records and ghost replay
- `ai_driver.gd`: first racing-line AI controller
- `themes.json`: reskinnable environment/UI definitions
- `theme_system.gd`: active theme selection and tokens
- `visual_renderer.gd`: shared drawing helpers for track, cars, HUD and touch rendering
- `static_world_layer.gd`: retained/cached environment and track presentation
- `weather_layer.gd`: retained animated dust/rain layer
- `tuning_panel.gd`: Handling Lab UI and tune persistence

This separation is intentional preparation for future map-derived tracks: a road/path source can eventually generate track geometry while the player independently chooses a visual/environment skin.

## Art production contract

The production art specification lives under `art/`.

Key rule: vehicle appearance is skin-specific while handling classes remain shared.

- Red Dirt: RWD SPORT -> Desert Prerunner; FWD HATCH -> Baja Compact; AWD RALLY -> Monster 4x4
- Brisbane Neon Rain: RWD SPORT -> Neon GT Coupe; FWD HATCH -> Neon Hot Hatch; AWD RALLY -> XC90 P2 Nightrunner

The production manifest defines the required and optional runtime art files. Required assets are validated automatically as part of the normal build.

Every normal build now runs:

    py tools/validate_art_assets.py

before the handling and race regression suites. `--allow-missing` remains available only for future art-development branches.

See:
- `art/ART_BIBLE.md`
- `art/GENERATION_BRIEFS.md`
- `art/INTEGRATION_CONTRACT.md`
- `art/asset_manifest.json`

## Roadmap

1. Tune the three cars by feel on keyboard/gamepad/touch and bake the preferred baselines.
2. Improve AI racecraft: overtaking, defensive lines and difficulty levels.
3. Add race/event selection and additional course geometry.
4. Add APS Grid tune submission/versioning before the external tuner build is published.
5. Begin the map-derived track pipeline without coupling map geometry to either visual skin.
