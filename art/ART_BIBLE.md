# APS Racer Art Bible

Status: production specification for v0.6.0 art pass  
Purpose: remove ambiguity before any final art is generated, commissioned, or integrated.

## 1. Non-negotiable art direction

APS Racer is a top-down arcade racer with two deliberately different visual worlds sharing the same race, handling, AI, course, ghost, and tuning systems.

### Red Dirt

Red Dirt is an Australian outback off-road racing fantasy influenced by Broken Hill / Silverton.

Vehicles are not normal road cars with dust on them. They are visibly off-road machines:
- desert prerunners
- Raptor / trophy-truck-like high-clearance trucks
- Baja / rally-raid compact off-roaders
- monster-truck-inspired AWD 4x4s

They must read as tough, tall, wide, dirty, mechanically exposed, and built to take impacts.

### Brisbane Neon Rain

Brisbane Neon Rain is an always-2am, always-raining, cyberpunk road-racing fantasy.

Vehicles are slick road machines:
- low GT / super-coupe shapes
- hot hatches / compact tuners
- low, wide AWD street weapons

They must read as expensive, modified, planted, smooth, aerodynamic, glossy, and rain-reflective.

## 2. Skin versus physics contract

The visual skin may radically change body shape, stance, wheel size, surface finish, lighting treatment, and vehicle identity.

The skin must NOT silently change:
- mass
- inertia
- wheelbase
- tyre model
- drivetrain
- brake balance
- engine force
- collision logic

Those remain in the vehicle preset.

The current physics classes map to skin-specific visual archetypes:

| Physics class | Red Dirt visual | Brisbane Neon Rain visual |
| --- | --- | --- |
| RWD SPORT | Desert Prerunner | Neon GT Coupe |
| FWD HATCH | Baja Compact | Neon Hot Hatch |
| AWD RALLY | Monster 4x4 | XC90 P2 Nightrunner |

These are working art archetype names, not necessarily final in-game model names.

## 3. Top-down camera rule

All vehicle masters must be true top-down orthographic art.

Do not use:
- isometric perspective
- three-quarter perspective
- visible horizon
- exaggerated front-facing grille perspective
- camera tilt

A tiny amount of form shading is permitted, but geometry must remain orthographic enough that vehicle footprint and heading are immediately readable.

## 4. Vehicle footprint rules

All six vehicle visuals must fit the current gameplay collision envelope closely enough that visual contact and physics contact feel coherent.

Target visual envelope at nominal runtime scale:
- length: 4.2â€“4.8 gameplay metres
- width excluding exaggerated tyre sidewall: 1.8â€“2.2 gameplay metres
- visual overshoot beyond collision footprint: <= 12%
- shadow overshoot may exceed body by <= 18%

Red Dirt vehicles may LOOK much taller/heavier through:
- larger tyre diameter
- wider exposed wheels
- suspension detail
- roof-mounted hardware
- high fender line
- compact cabin
- aggressive body proportions

Do not make the Red Dirt AWD vehicle a literal stadium monster truck whose visible body is twice the collision footprint.

## 5. Master vehicle asset standard

Master canvas:
- 1024 x 1024 px
- transparent RGBA
- sRGB
- no baked background
- vehicle aligned vertically in source with nose pointing up
- vehicle centre of rotation exactly at canvas centre
- body occupies approximately 76â€“84% of canvas height
- minimum transparent margin 7% on every side

Runtime downscale target:
- nominal on-screen length 80â€“140 px depending on camera zoom
- all detail must survive at 96 px vehicle length

Every vehicle package must include:
- full composite
- body/base colour layer
- glass layer
- shadow layer
- front wheel sprite
- rear wheel sprite
- headlights emission layer
- brake/tail-light emission layer
- optional skin-specific overlay

Red Dirt optional overlay:
- dirt / mud / dust accumulation

Brisbane Neon Rain optional overlay:
- wet specular / neon reflection / underglow

## 6. Vehicle silhouette acceptance

At 96 px long and in grayscale, each of the three cars within one skin must still be distinguishable by silhouette.

Red Dirt:
- Desert Prerunner: long nose, pickup/truck bed or rear deck, wide front track
- Baja Compact: short wheelbase, compact cabin, rally-raid/buggy stance
- Monster 4x4: huge tyre read, blunt muscular body, widest stance

Brisbane Neon Rain:
- Neon GT Coupe: long-low two-door proportions
- Neon Hot Hatch: short, upright rear, compact proportions
- XC90 P2 Nightrunner: tall, boxy long-roof P2-era luxury SUV proportions with roof rails and strong vertical rear-light read

## 7. Red Dirt vehicle detail language

Required cues:
- high ground clearance
- large chunky tyres
- exposed or visually implied long-travel suspension
- protective bumper / bash bar language
- roof or bonnet hardware kept readable from above
- dusty matte / satin paint
- scuffs, dirt, faded decals used sparingly
- warm sunbaked highlights
- no glossy showroom finish

Avoid:
- licensed Ford branding
- copied Raptor grille
- copied Monster Jam liveries
- brand logos
- exact real-world truck replicas

The brief is "Raptor / trophy truck / monster truck energy", not trademark imitation.

## 8. Brisbane Neon Rain vehicle detail language

Required cues:
- low ride height
- tight wheel arches
- clean aero surfaces
- glossy wet finish
- dark glass
- road-focused tyres
- narrow, crisp lighting elements
- restrained neon reflection / underglow
- modified but not cartoonishly over-bodied

Avoid:
- flying-car styling
- giant sci-fi thrusters
- impossible wheel layouts
- excessive Tron-line coverage
- generic supercar copies

The cars should still look like plausible terrestrial road machines at 2am in wet Brisbane.


## 9. Shared environment readability rules

Environment detail exists to sell speed and place, never to hide the race line.

At gameplay scale:
- road edge must be readable within 100 ms glance time
- barriers must separate clearly from road and runoff
- checkpoint guidance must remain visible above decorative detail
- prop density within 2.5 gameplay metres of the driveable edge must be deliberately sparse
- no decorative object may be visually confused with a checkpoint marker
- all high-contrast props should sit outside the immediate racing corridor

Static world assets should be designed to tile or repeat without obvious seams.

## 10. Red Dirt environment kit

Core surface language:
- iron-rich red earth
- compacted racing line
- lighter dusty shoulder
- darker tyre-rut overlays
- occasional gravel and stone breakup
- low-frequency texture; avoid noisy photographic dirt

Required environment asset families:
- packed dirt base
- loose dirt/runoff base
- tyre rut overlay
- scrub patch A/B/C
- rock cluster A/B/C
- fence post
- corrugated fence segment
- tyre stack barrier
- temporary steel barrier
- event cone
- drum/barrel
- small shed silhouette
- power/telegraph pole
- faded directional/event sign

Palette target:
- iron red #A94D2F
- dark rust #74301F
- sunbaked ochre #C76A43
- dust tan #E1AA72
- charcoal brown #3C211A
- faded cream #F2E0C3
- scrub olive #7F7541

Lighting:
- hard dry daylight
- restrained specular
- shadows warm-neutral, not blue
- no lush green

## 11. Brisbane Neon Rain environment kit

Core surface language:
- blue-black wet asphalt
- soft reflected light pools
- glossy road paint
- puddle sheen
- controlled cyan/magenta accents
- dark city massing outside the track

Required environment asset families:
- wet asphalt base
- darker wet patch
- reflected-light overlay
- lane marking solid
- lane marking broken
- reflective road stud
- neon barrier strip
- concrete crash barrier
- steel railing
- bollard
- light pole
- compact billboard/sign
- rooftop/city-block silhouette A/B/C
- drain/grate
- puddle patch A/B/C

Palette target:
- asphalt #121923
- deep asphalt #090D14
- city black #05070D
- structural grey #5A6D7D
- cyan #34D8FF
- pale cyan #7BDCFF
- magenta #FF3EBF
- wet highlight #D7F6FF

Lighting:
- always night
- always raining
- approximately 02:00 visual mood
- no sunset/orange daylight
- neon accents should illuminate, not repaint the whole screen

## 12. Course-specific visual rules

Both ROUND and FIGURE 8 must use the same skin kit.

ROUND:
- broad, sweeping readability
- environmental props can be distributed around the outer and inner perimeter
- long straights can carry road wear, ruts, reflections, signage, and light pools

FIGURE 8:
- central crossover must be unmistakable
- same-level intersection in current gameplay
- central crossing must not visually imply a bridge
- checkpoint/start line cannot disappear under reflections or dirt
- opposing road branches must remain separated by edge treatment until the actual crossover
- prop density around the crossover should be near zero

## 13. HUD layout contract

The HUD layout is shared across skins. Only presentation tokens change.

Persistent information:
- selected vehicle
- active skin
- speed
- lateral G
- longitudinal G
- surface
- race position
- lap
- current lap time
- best lap
- last lap
- sector
- rival status

Top utility controls:
- SKIN
- ROUND / FIG 8
- DATA
- TUNE
- CAR
- RESET

Mobile drive controls:
- steer left
- steer right
- BRAKE
- GO
- HANDBRAKE

HUD must remain fully readable at:
- 1280 x 720 browser baseline
- 1080 x 2400 portrait-capable Android display used in landscape
- 960 x 540 minimum supported logical viewport

Minimum touch target:
- 44 CSS px absolute minimum
- 56â€“104 px preferred for driving controls

## 14. UI style tokens

Shared:
- 8â€“12 px panel corner radius at 1280 x 720
- 1â€“2 px border
- strong numeric hierarchy
- no bevelled 2000s game UI
- no skeuomorphic speedometer
- no excessive glow

Red Dirt UI:
- dark warm charcoal panel
- faded cream text
- hazard-orange accent
- dusty amber secondary accent
- rugged but clean; avoid distressed fonts

Brisbane Neon Rain UI:
- blue-black translucent panel
- near-white text
- cyan primary accent
- magenta secondary accent
- subtle edge glow only
- slick instrument-cluster feel

Typography:
- one primary sans family
- tabular numerals required
- uppercase labels acceptable
- avoid novelty cyberpunk fonts
- avoid stencil/military fonts for Red Dirt

## 15. UI asset standard

Where raster UI art is needed:
- source at 2x target scale
- transparent PNG
- no baked text
- no baked numbers
- no skin name baked into generic shared panels

Prefer code/9-slice for:
- panel bodies
- buttons
- borders
- sliders
- selection states

Raster assets should focus on:
- icons
- subtle textures
- special overlays
- countdown embellishment
- finish treatment

## 16. Required icon set

Shared icons, monochrome masters:
- skin
- course
- telemetry/data
- tuning
- car
- reset
- save
- load
- delete
- bake
- copy
- close
- left
- right
- throttle
- brake
- handbrake
- ghost
- rival
- best lap
- sector

Master:
- 128 x 128 px SVG preferred
- if raster: 256 x 256 transparent PNG
- line weight must survive at 20 px display

## 17. VFX language

VFX must be short-lived and bounded. No effect should obscure the player for more than 250 ms.

Red Dirt:
- broad soft dust puffs
- granular dirt kick
- darker rut/skid line
- tiny warm impact grit
- no white road-car tyre smoke as default

Brisbane Neon Rain:
- narrow wet spray
- short specular splash
- dark wet skid
- tiny cool-white sparks on hard barrier contact
- restrained reflected-light streaks

Shared:
- checkpoint pulse
- lap-complete flash
- ghost shimmer
- rival marker
- start countdown

## 18. Ghost visual

Ghost must never be confused with:
- player
- rival
- checkpoint

Specification:
- 12â€“20% interior opacity
- 45â€“60% outline opacity
- skin primary accent
- no shadow
- no tyre spray/dust
- no collision sparks
- optional subtle 2â€“3 Hz opacity shimmer later

## 19. Rival visual

Rival remains a solid car.

Required distinction:
- RIVAL marker above vehicle
- marker uses danger/accent token, not player-car body colour
- optional thin roof stripe or number plate strip
- do not recolour the entire rival to fluorescent red

## 20. Countdown and finish presentation

Countdown:
- numerals 3 / 2 / 1
- centre screen
- high contrast
- brief scale/opacity animation allowed
- no giant full-screen explosion

GO:
- same visual family as countdown
- maximum on-screen emphasis around 700â€“900 ms

Finish:
- position
- total time
- best lap indication if applicable
- must not hide all track context
- should read as polished race UI, not arcade clip-art

## 21. Asset source and export policy

Source art:
- store layered masters under `art/source/`
- source files may be PSD/KRA/ORA/SVG depending on asset type
- preserve editable text and vector shapes
- do not flatten masters unless unavoidable

Runtime exports:
- store under `art/export/` during art production
- transparent PNG for sprites
- SVG for simple icons where Godot import quality is acceptable
- texture atlases may be introduced after visual approval
- do not prematurely atlas assets while iteration is active

No runtime asset may contain:
- visible watermark
- stock-image licensing mark
- artist signature
- brand logo not owned/cleared for the project
- generated text pretending to be signage unless intentionally fictional and legible

## 22. Pixel density and filtering

Primary runtime look is crisp semi-realistic 2D, not pixel art.

Texture filtering:
- linear filtering acceptable
- no nearest-neighbour pixel-art treatment
- mipmaps enabled where they improve scaled environment props
- transparent sprite edges must be clean at 0.5x scale

Every candidate vehicle must be reviewed at:
- 256 px long
- 128 px long
- 96 px long
- 72 px long

If identity or nose direction fails at 96 px, revise the silhouette.

## 23. Shadow standard

Vehicle shadows:
- separate transparent layer
- soft-edged
- offset subtly down/right in source orientation
- opacity 25â€“45%
- Red Dirt shadow slightly harder/drier
- Brisbane shadow softer and darker against wet asphalt
- do not bake shadow into body composite

Environment prop shadows:
- may be baked when the object is static and skin-specific
- must respect each skin's light language

## 24. Vehicle emission standard

Headlight/brake/underglow art must be isolated from the base body.

Headlights:
- white to warm-white in Red Dirt
- neutral/cool-white in Brisbane Neon Rain

Brake lights:
- red only
- no magenta brake lights

Brisbane underglow:
- optional, subtle
- cyan/magenta/violet only
- must not extend beyond 12% of vehicle width as a bright halo
- should read as reflected light, not a floating aura

## 25. Damage and dirt scope

Not required for v0.6.0 production pass.

Prepare layer structure so later versions can add:
- dust accumulation
- mud splash
- panel scuff
- cracked light
- scrape overlay

Do not spend production time on full damage deformation yet.

## 26. Asset review gates

An asset is not accepted because it looks good at full resolution.

### Vehicle acceptance
Must pass:
1. true top-down orthographic check
2. transparent background check
3. heading readability at 96 px
4. silhouette differentiation
5. no brand/IP imitation
6. correct centre pivot
7. collision-envelope coherence
8. skin language match
9. clean alpha edges
10. no baked environment lighting that breaks the other course

### Environment acceptance
Must pass:
1. tiles/repeats cleanly where required
2. does not hide road edge
3. palette matches skin
4. no fake perspective incompatible with top-down camera
5. readable at gameplay zoom
6. prop silhouettes distinct
7. low visual noise
8. works on both ROUND and FIGURE 8

### UI acceptance
Must pass:
1. readable at 960 x 540
2. touch targets remain clear
3. tabular numerals render cleanly
4. skin styling does not change control position
5. no baked text in reusable panel art
6. active/inactive/pressed states are visually distinct
7. no excessive glow or texture noise

## 27. Generation / commissioning rule

Generate or commission assets in families, not one-offs.

Approval order:
1. one representative vehicle from each skin
2. one representative environment frame from each skin
3. one shared HUD mockup rendered in both skin treatments
4. only after those four directions are approved, generate the remainder

This avoids producing dozens of internally inconsistent assets.

## 28. First approval candidates

Create these first:

### Red Dirt hero vehicle
Desert Prerunner:
- original unbranded trophy-truck/Raptor-inspired form
- RWD visual archetype
- high clearance
- big tyres
- wide arches
- compact cabin
- dusty red/graphite/cream livery
- top-down orthographic

### Brisbane Neon Rain hero vehicle
Neon GT Coupe:
- original unbranded low GT/super-coupe form
- RWD visual archetype
- glossy dark body
- crisp light signatures
- wet reflective finish
- restrained cyan/magenta reflected accents
- top-down orthographic

These two establish whether the skin split is working.

## 29. Production quantities

v0.6.0 target quantities:

Vehicles:
- 6 distinct skin-specific vehicle composites
- 6 body layers
- 6 glass layers
- 6 shadow layers
- 6 headlight emission layers
- 6 brake emission layers
- 12 wheel sprites minimum
- 6 optional skin-overlay layers

Shared UI:
- 21 monochrome icons
- 1 HUD layout system
- 1 Handling Lab layout system
- 1 touch-control layout system
- 4 generic panel/button states

Red Dirt environment:
- 2 surface bases
- 1 rut overlay
- 3 scrub variants
- 3 rock variants
- 8â€“10 prop/barrier assets
- 1 start/finish treatment
- 1 checkpoint treatment
- 2 dust VFX sprites/frames or equivalent procedural textures

Brisbane Neon Rain environment:
- 2 asphalt/wet surface bases
- 3 puddle/reflection overlays
- 2 lane marking types
- 2 barrier types
- 8â€“10 urban prop assets
- 1 start/finish treatment
- 1 checkpoint treatment
- 2 spray/splash VFX sprites/frames or equivalent procedural textures

Expected first-pass production set:
approximately 80â€“95 individual runtime files before atlas consolidation.

## 30. v0.6.0 definition of done

v0.6.0 art pass is complete when:
- all six skin-specific cars replace procedural body art
- both skins have production-quality track/environment treatments
- HUD and Handling Lab use approved shared layout + skin tokens
- touch controls have final icon treatment
- ghost and rival presentation is final enough for external tuning
- ROUND and FIGURE 8 remain equally readable
- Web memory remains stable after asset integration
- 1280 x 720 Web, Android landscape, and Windows builds pass visual smoke tests
- no required runtime art is still a procedural placeholder except intentionally procedural weather/line effects

## 31. Explicitly deferred

Not part of this asset pass:
- Google Maps / map-derived geometry
- licensed real-world car replicas
- vehicle deformation
- full livery editor
- crowds
- animated pit crews
- 3D conversion
- bridge/underpass Figure 8 logic
- cinematic camera
- photorealism

The target is a coherent, attractive, expandable 2D racing identityâ€”not final AAA content.
