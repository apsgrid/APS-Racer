# APS Racer

Top-down racing prototype built in Godot 4.7.2 with a custom four-wheel vehicle simulation.

## Current milestone: handling build

The game now has a proper handling-test loop rather than a single generic car.

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
- Grass runoff between road and barriers
- Braking markers
- Slalom markers
- Skid marks
- Tyre smoke when rear tyres exceed the slip/grip threshold
- Speed-dependent camera zoom and look-ahead

### Controls

Keyboard:
- W / Up: throttle
- S / Down: brake / reverse at low speed
- A/D or Left/Right: steering
- Space: handbrake
- R: reset
- 1/2/3: select car

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
- CAR
- RESET

## Automated handling baseline

Run:

    godot --headless --path . --script res://handling_tests.gd

Current baseline:

- RWD Sport: 0-100 km/h 4.97 s; 100-0 km/h 36.5 m
- FWD Hatch: 0-100 km/h 5.60 s; 100-0 km/h 36.4 m
- AWD Rally: 0-100 km/h 4.87 s; 100-0 km/h 38.9 m
- Sustained cornering sanity check: about 1.0 g for all three presets

The numbers are regression baselines, not final realism targets.

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

Vehicle handling lives in vehicle_sim.gd rather than relying on a stock engine vehicle controller. Track geometry and collision live in track_model.gd. Godot provides rendering, input, packaging, audio and platform support while the vehicle model remains independently tunable.

## Next gameplay milestones

1. Verify the handling build by feel on keyboard/gamepad/touch and tune the three cars apart.
2. Add checkpoints, lap timing, best lap and ghost replay.
3. Add one AI opponent using a racing-line controller.
4. Add race start/finish flow and a three-lap event.
5. Replace placeholder car/track graphics only after the driving model is approved.
