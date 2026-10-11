# APS Racer

Top-down racing prototype built in Godot 4.7.2 with a custom four-wheel vehicle simulation.

## Current milestone: first race build

The game now combines the custom handling model, reskinnable presentation layer, compact race HUD, mobile controls, Handling Lab, persistent lap records, ghost replay, and a first AI opponent in a complete three-lap event.

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

### Cars

Press 1/2/3, D-pad left/right, or the CAR touch button to switch between:

1. RWD Sport
2. FWD Hatch
3. AWD Rally

These use the same physics code with different vehicle parameters and drivetrain torque distribution.

### Test circuit

- Rounded high-speed circuit
- Theme-selectable surface grip profile
- Braking/slalom markers rendered as environment-appropriate props
- Skid marks
- Dust or wet-road spray
- Speed-dependent camera zoom and look-ahead

### Visual skins

Press **G** or tap **SKIN** to switch the presentation without changing the track geometry or race logic.

**Red Dirt**
- Broken Hill / Silverton influence
- packed red-earth racing surface
- loose-dirt runoff
- ochre terrain, scrub, rocks, fence posts and dust
- rugged warm UI treatment

**Brisbane Neon Rain**
- Brisbane at about 02:00
- permanently raining
- wet asphalt and road spray
- neon cyan/magenta edges and reflections
- city-block/signage treatment
- dark translucent cyberpunk UI

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

Race records are stored in `user://aps_racer_race_records.json`. The ghost key includes the active visual skin and selected car so Red Dirt and Brisbane Neon Rain retain independent records.

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
- H: toggle telemetry drawer
- T / F1: Handling Lab

Gamepad:
- Left stick: steering
- Right trigger or A: throttle
- Left trigger or B: brake
- X: handbrake
- D-pad left/right: change car

Touch:
- Left/right steering
- GO
- BRAKE
- HANDBRAKE
- SKIN
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

- RWD Sport: 0-100 km/h 4.97 s; 100-0 km/h 36.5 m
- FWD Hatch: 0-100 km/h 5.60 s; 100-0 km/h 36.4 m
- AWD Rally: 0-100 km/h 4.87 s; 100-0 km/h 38.9 m
- Sustained cornering sanity check: about 1.0 g for all three presets

The numbers are regression baselines, not final realism targets.

Race baseline:

- ordered and directional checkpoint validation
- three-lap event completion
- sector timing and best-lap retention
- ghost capture/playback
- AI completes three Red Dirt laps in about 44 seconds while remaining predominantly on-track

## Build

PowerShell:

    .\tools\build.ps1

The build script runs handling tests first, then exports all three targets:

- Web: builds/web/index.html
- Windows: builds/windows/APSRacer.exe
- Android ARM64 debug APK: builds/android/APSRacer-debug.apk

Use -WebOnly, -WindowsOnly, -AndroidOnly, or -SkipTests when appropriate.

The Web export has been smoke-tested in Chrome with WebGL 2 and the Compatibility renderer. The Android APK is zip-aligned, debug-signed, and targets Android 16 / API 36.

## Platform strategy

Primary targets:

- Windows development/reference build
- Android native APK
- Web browser build

The project uses GDScript and Godot's Compatibility renderer so Web and Android remain first-class targets.

## Architecture

- `vehicle_sim.gd`: vehicle dynamics and tunable parameters
- `vehicle_presets.json`: baked car setups
- `track_model.gd`: course geometry, barriers, surface queries, race gates and racing line
- `race_system.gd`: countdown, checkpoints, sectors, laps, records and ghost replay
- `ai_driver.gd`: first racing-line AI controller
- `themes.json`: reskinnable environment/UI definitions
- `theme_system.gd`: active theme selection and tokens
- `visual_renderer.gd`: track, environment, weather, cars, HUD and touch rendering
- `tuning_panel.gd`: Handling Lab UI and tune persistence

This separation is intentional preparation for future map-derived tracks: a road/path source can eventually generate track geometry while the player independently chooses a visual/environment skin.

## Next gameplay milestones

1. Tune the three cars by feel on keyboard/gamepad/touch and bake the preferred baselines.
2. Improve AI racecraft: overtaking, defensive lines and difficulty levels.
3. Add race/event selection and additional course geometry.
4. Add APS Grid tune submission/versioning before the external tuner build is published.
5. Begin the map-derived track pipeline without coupling map geometry to either visual skin.
