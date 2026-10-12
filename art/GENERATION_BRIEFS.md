# APS Racer Generation / Commissioning Briefs

These briefs are for concept generation and production art. They supplement, not replace, ART_BIBLE.md and asset_manifest.json.

## Global prompt prefix

Use this conceptual prefix for all vehicle generations:

"true top-down orthographic racing game vehicle asset, transparent background, centred exactly on canvas, nose pointing straight up, no camera tilt, no isometric perspective, no ground plane, no scenery, clean production sprite, readable silhouette at small size, semi-realistic stylised 2D game art, physically plausible vehicle proportions"

Global negative constraints:
- no three-quarter view
- no horizon
- no road under vehicle
- no driver visible through roof
- no brand logos
- no readable manufacturer badges
- no text labels
- no watermark
- no weaponry
- no fantasy hover parts
- no exaggerated perspective
- no clipped tyres or shadows

## Vehicle approval sequence

Do NOT generate all six production vehicles at once.

Approval pass A:
1. Red Dirt Desert Prerunner
2. Brisbane Neon Rain Neon GT Coupe

Once both are approved for:
- top-down geometry
- rendering style
- detail density
- silhouette readability
- material response

then generate the remaining four vehicles using the approved examples as direct style references.

---

# RED DIRT VEHICLES

## RD-01 Desert Prerunner

Physics mapping: RWD SPORT

Core shape:
- original unbranded desert prerunner / trophy-truck form
- Raptor-like energy without copying Ford design language
- long front section
- compact cabin
- short rear deck / pickup bed impression
- very wide stance
- large off-road tyres visible outside body
- long-travel suspension cues
- protective front/rear structure

Surface:
- dusty satin paint
- warm red / graphite / faded cream base livery
- light scuffing
- dust concentrated behind wheel arches and rear body
- no deep mud

Top-down readability:
- front unmistakable through bonnet/nose proportion
- rear unmistakable through deck/bed geometry
- exposed tyres form strong silhouette

Do not:
- copy Ford grille/headlight signature
- use giant stadium monster-truck tyres
- add roof cage so dense it obscures body
- make it a normal pickup with just bigger wheels

## RD-02 Baja Compact

Physics mapping: FWD HATCH

Core shape:
- compact rally-raid / Baja-style short-wheelbase vehicle
- lifted compact body
- chunky tyres
- strong fender protection
- short nose
- short rear
- slightly buggy-like toughness without becoming an open-frame dune buggy

Surface:
- dusty off-white / orange / dark grey or muted blue
- utilitarian panels
- subtle rally-number panel area without actual number/text baked in

Top-down readability:
- shortest vehicle in Red Dirt family
- most compact cabin/body mass
- noticeably narrower/shorter than Monster 4x4

Do not:
- make it look like a road hatch on all-terrain tyres
- make it open-wheel
- make it look military

## RD-03 Monster 4x4

Physics mapping: AWD RALLY

Core shape:
- monster-truck-inspired AWD 4x4
- highest and widest visual stance
- enormous tyre read relative to body
- blunt square body
- strong roof mass
- heavy wheel arches
- visible suspension/axle hints from top
- still normalized to gameplay footprint

Surface:
- dark green / yellow / cream or charcoal / ochre options
- rugged matte finish
- dust and impact wear
- minimal chrome

Top-down readability:
- largest wheel-to-body ratio
- widest stance
- shortest apparent nose relative to body
- must read instantly as the heavyweight AWD choice

Do not:
- literal Monster Jam proportions
- branded monster-truck liveries
- giant novelty body shells
- wheels extending so far that collision feels dishonest

---

# BRISBANE NEON RAIN VEHICLES

## BNR-01 Neon GT Coupe

Physics mapping: RWD SPORT

Core shape:
- original unbranded low GT / super-coupe
- long low nose
- tapering cabin
- wide rear haunches
- elegant rather than extreme
- tight road tyres
- aerodynamic surfaces

Surface:
- glossy wet dark graphite / deep crimson / midnight blue
- dark glass
- crisp white headlight signature
- red brake lights
- restrained cyan/magenta wet reflections
- optional subtle underbody reflected glow

Top-down readability:
- longest/lowest perceived silhouette in Neon family
- unmistakable coupe roof
- clear front/rear light separation

Do not:
- copy Ferrari/Lamborghini/Porsche/Audi design signatures
- use huge wings
- cover body in neon strips
- sci-fi hover-car styling

## BNR-02 Neon Hot Hatch

Physics mapping: FWD HATCH

Core shape:
- compact performance hatch
- short nose
- upright rear
- tight wheelbase
- subtle wide arches
- roof spoiler small enough to preserve silhouette
- road-focused stance

Surface:
- glossy electric blue / silver / deep teal
- wet reflections
- modest cyan accents
- dark panoramic roof optional

Top-down readability:
- shortest Neon vehicle
- obvious squared rear
- clear hot-hatch identity

Do not:
- make it a mini supercar
- make it SUV/crossover height
- add giant racing wing

## BNR-03 Neon AWD Street Weapon

Physics mapping: AWD RALLY

Core shape:
- low, wide AWD super-saloon / shooting-brake / rally-derived street machine
- longer roof than GT
- muscular arches
- practical central cabin volume
- planted stance
- optional restrained rear wing or roof spoiler

Surface:
- glossy charcoal / pearl white / deep violet
- wet highlights
- cyan/magenta reflection accents
- crisp light bars

Top-down readability:
- widest Neon vehicle
- longer roof mass than GT
- aggressive but road-plausible

Do not:
- turn it into a rally car with mud tyres
- make it cyber tank
- use full-width neon body outlines

---

# ENVIRONMENT CONCEPT BRIEFS

## Red Dirt hero environment frame

Create a top-down racing-game environment concept showing a section of track, not a cinematic landscape.

Must show:
- packed red-earth racing surface
- lighter loose-dirt shoulders
- visible darker tyre ruts
- sparse scrub
- scattered rock clusters
- one tyre-stack or temporary steel barrier family
- corrugated fence/event infrastructure
- warm dry daylight
- low visual clutter near road edge
- no horizon

Mood:
"Broken Hill / Silverton off-road club racing, dry, iron-rich, rugged, sunbaked, functional"

Avoid:
- lush green vegetation
- desert dunes
- American Southwest roadside iconography
- Western cowboy clichés
- photoreal aerial photography look

## Brisbane Neon Rain hero environment frame

Create a top-down racing-game environment concept showing a section of wet urban road.

Must show:
- blue-black wet asphalt
- subtle puddles
- reflective lane paint
- cyan/magenta reflected light pools
- concrete/neon barrier family
- bollards/railings/light poles
- dark city massing outside racing corridor
- visible rain/spray treatment
- no horizon
- road edge always readable

Mood:
"Brisbane at about 2am, permanently raining, sleek cyberpunk street-racing fantasy, dark and reflective rather than garish"

Avoid:
- Tokyo signage clichés
- dense kanji/neon-wall aesthetic
- Blade Runner imitation
- daytime city
- purple everywhere
- rainbow neon
- flying vehicles

---

# UI CONCEPT BRIEF

Create one shared HUD layout shown in two skin treatments.

Layout must preserve current functional structure:
- vehicle/speed block top-left
- race block top-centre
- utility buttons top-right
- mobile driving controls bottom corners
- optional telemetry drawer
- Handling Lab as a right-side panel

Red Dirt treatment:
- dark warm translucent panels
- faded cream type
- hazard orange primary
- dusty amber secondary
- subtle rugged texture
- clean modern typography

Brisbane Neon Rain treatment:
- blue-black translucent panels
- white/cool-grey type
- cyan primary
- magenta secondary
- restrained glow
- sleek instrument-cluster styling

Do not:
- redesign control positions
- add analogue speedometer
- use grunge fonts
- use novelty cyberpunk fonts
- over-glow all borders

---

# Production rendering consistency

For a family batch, keep constant:
- camera projection
- light direction
- shadow direction
- canvas framing
- detail density
- edge sharpness
- material rendering style
- alpha treatment

Vehicle master light direction:
- primary light from upper-left of canvas
- shadow offset slightly lower-right
- form shading subtle enough that 180-degree vehicle rotation in-game does not look obviously incorrectly lit

This is a compromise for top-down sprite rotation. Avoid hard directional cast-light effects on the body.

# Reference contact sheet requirement

Before final integration, produce contact sheets:
- all 3 Red Dirt vehicles side-by-side at 256 px and 96 px
- all 3 Brisbane Neon Rain vehicles side-by-side at 256 px and 96 px
- both skin environment kits at gameplay zoom
- shared UI in both skins at 1280 x 720

No production batch is accepted without these comparison sheets.
