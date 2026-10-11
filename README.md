# APS Racer Prototype

A top-down racing prototype built in Godot 4.7.2 using a custom four-wheel vehicle simulation.

## Current milestone

- Custom 120 Hz vehicle physics substep
- Four tyre contact patches
- Finite grip budget / combined longitudinal and lateral grip
- Longitudinal weight transfer
- RWD acceleration
- Braking and low-speed reverse
- Handbrake rear-grip reduction
- Asphalt and grass surface grip
- Speed-sensitive steering
- Speed-sensitive camera zoom/look-ahead
- Live telemetry
- Keyboard controls
- Multi-touch Android/browser controls
- Simple test circuit

## Controls

- W / Up: throttle
- S / Down: brake / reverse at low speed
- A/D or Left/Right: steering
- Space: handbrake
- R: reset
- Touch: on-screen controls

## Platform targets

Primary targets are Windows development, Android native export, and Web export. The project uses GDScript and the Compatibility renderer to keep the browser target viable.

## Architecture

Vehicle handling lives in `vehicle_sim.gd` rather than relying on a stock engine car controller. Godot provides rendering, input, packaging and platform support while the vehicle model remains independently tunable.
