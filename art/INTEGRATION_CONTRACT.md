# APS Racer Art Integration Contract

This file defines where approved art goes and what runtime code may assume.

## 1. Runtime path convention

Vehicle exports:

`art/export/vehicles/<skin>/<vehicle_id>/`

Example:

`art/export/vehicles/red_dirt/desert_prerunner/desert_prerunner_composite.png`

Environment exports:

`art/export/skins/<skin>/environment/`

Shared UI:

`art/export/shared/ui/`

Shared VFX:

`art/export/shared/vfx/`

## 2. File naming

All runtime filenames:
- lowercase
- ASCII
- snake_case
- no spaces
- no version suffix in final approved filename
- no words such as final, latest, new, test, approved

Version history belongs in Git/source files, not runtime filenames.

## 3. Vehicle package naming

For vehicle id `desert_prerunner`:

- `desert_prerunner_composite.png`
- `desert_prerunner_body.png`
- `desert_prerunner_glass.png`
- `desert_prerunner_shadow.png`
- `desert_prerunner_front_wheel.png`
- `desert_prerunner_rear_wheel.png`
- `desert_prerunner_headlights.png`
- `desert_prerunner_brakelights.png`
- optional `desert_prerunner_dirt_overlay.png`

The same pattern applies to all six vehicle ids.

## 4. Orientation and pivot

Vehicle assets:
- nose points toward negative image Y / canvas top
- pivot is canvas centre
- no cropping to content bounds
- every 1024 x 1024 vehicle layer uses identical canvas dimensions and alignment
- transparent pixels are intentional and must be preserved

Godot may rotate the sprite around the exact centre without per-asset correction.

## 5. Alpha

Vehicle and prop PNGs:
- RGBA
- straight alpha
- transparent background
- no matte fringe
- no opaque black/white background hidden behind alpha

Shadow layers:
- RGB colour allowed
- alpha carries opacity
- no hard rectangular edge

## 6. Colour management

- sRGB exports
- no CMYK
- no embedded exotic colour profile required
- emission layers authored visually in sRGB
- no HDR texture requirement for v0.6.0

## 7. Vehicle compositing order

Back to front:

1. shadow
2. rear wheels
3. front wheels
4. body
5. glass
6. skin overlay
7. headlights
8. brake lights

The composite file is for fallback/preview. Runtime may use separated layers for steering, lights, dirt/wet effects and later damage.

## 8. Environment compositing

Static base:
1. ground/surface
2. low-frequency variation
3. ruts/puddles/reflections
4. road markings
5. props
6. barriers
7. checkpoint/start-finish presentation

Dynamic:
1. car shadows
2. cars
3. tyre dust/spray
4. ghost/rival indicators
5. weather foreground
6. HUD

## 9. Texture import intent

Vehicles:
- linear filtering
- mipmaps on if downscale quality benefits
- repeat disabled

Tileable surfaces:
- repeat enabled
- mipmaps enabled

UI icons:
- filtering enabled
- repeat disabled

Pixel-art import settings must not be used.

## 10. Fallback rule

Until every required production asset is approved:
- current procedural rendering remains the fallback
- do not partially replace only one vehicle in a way that leaves the roster stylistically inconsistent in a public build

An internal art-review build may opt into partial assets.

## 11. Skin mapping

Runtime skin id `red_dirt` maps:
- rwd_sport -> desert_prerunner
- fwd_hatch -> baja_compact
- awd_rally -> monster_4x4

Runtime skin id `brisbane_neon_rain` maps:
- rwd_sport -> neon_gt
- fwd_hatch -> neon_hot_hatch
- awd_rally -> neon_xc90_p2

Changing skin may therefore change the visible vehicle body completely while preserving the underlying selected physics class.

## 12. Course independence

No vehicle or environment asset may contain ROUND or FIGURE 8 geometry baked into it unless the manifest explicitly labels the asset as a course-specific track UI element.

Both skins must function on:
- ROUND
- FIGURE 8
- future map-derived tracks

## 13. Approval state

Source art may use:
- `concept`
- `review`
- `approved`

Runtime export directories contain approved files only.

Do not use filename suffixes for approval state.

## 14. Automated validation

Run:

`python tools/validate_art_assets.py`

During pre-production, use:

`python tools/validate_art_assets.py --allow-missing`

To create the expected export folder tree automatically:

`python tools/validate_art_assets.py --allow-missing --scaffold`

The validator checks:
- manifest parses
- required file paths
- dimensions
- PNG mode / alpha where applicable
- SVG presence for icons
- duplicate filenames
- unknown extra runtime files

Visual checks such as silhouette, orientation and art quality remain human approval gates.
