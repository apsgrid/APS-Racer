# APS Racer Art Production

This directory is the production contract for the v0.6.0 visual asset pass.

Read in this order:

1. `ART_BIBLE.md` — visual language, dimensions, acceptance rules, skin-specific vehicle direction.
2. `GENERATION_BRIEFS.md` — prompts/commissioning briefs for the six vehicles, two environments and UI.
3. `INTEGRATION_CONTRACT.md` — exact paths, naming, orientation, compositing and Godot integration rules.
4. `asset_manifest.json` — machine-readable list of required runtime assets.

Current production contract:
- 6 skin-specific vehicle packages
- 21 shared UI icons
- 22 Red Dirt environment/VFX assets
- 24 Brisbane Neon Rain environment/VFX assets
- 115 required runtime files
- 9 optional runtime files

Red Dirt vehicle family:
- RWD SPORT -> Desert Prerunner
- FWD HATCH -> Baja Compact
- AWD RALLY -> Monster 4x4

Brisbane Neon Rain vehicle family:
- RWD SPORT -> Neon GT Coupe
- FWD HATCH -> Neon Hot Hatch
- AWD RALLY -> Neon AWD Street Weapon

Run the pre-production validator with:

`py tools/validate_art_assets.py --allow-missing`

Create the expected export folder tree with:

`py tools/validate_art_assets.py --allow-missing --scaffold`

Once production art is expected to be complete, run:

`py tools/validate_art_assets.py`

Editable masters belong under `art/source/` and visual references under `art/reference/`. Both are hidden from Godot imports via `.gdignore`. Approved runtime art belongs under `art/export/`.
