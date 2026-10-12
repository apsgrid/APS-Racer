import json,time,urllib.request
C='http://127.0.0.1:8188'
PREFIX="""TRUE 90-DEGREE TOP-DOWN ORTHOGRAPHIC GAME SPRITE. Camera directly overhead looking straight down. Single vehicle only. Nose points straight toward top edge. Entire vehicle visible with margin. Centered exactly on canvas. Isolated on perfectly uniform pure bright green chroma key background. No ground plane, no road, no scenery, no horizon, no perspective, no three-quarter angle, no text, no logos. High-detail realistic racing game asset, crisp clean overhead silhouette, physically plausible proportions. """
SPECS=[
("red_dirt","desert_prerunner",919133,"original unbranded Australian desert trophy-truck prerunner, extremely wide track, long-travel suspension visible from directly above, large exposed chunky off-road tyres, compact cabin, short pickup-style rear deck, protective race bumpers, dusty satin red graphite and faded cream paint, rugged Baja racing machine, clearly not a normal road pickup"),
("red_dirt","baja_compact",919151,"original compact Baja rally-raid racer, short wheelbase, enclosed compact cabin, lifted lightweight body, exposed chunky off-road tyres, strong fender protection, small roof scoop and rally hardware, dusty off-white orange and graphite paint, agile tough off-road silhouette"),
("red_dirt","monster_4x4",919177,"original monster-truck-inspired AWD 4x4 race machine, very wide stance, huge off-road tyres but still plausible racing proportions, blunt muscular body, heavy arches, visible suspension components from above, compact cabin, matte charcoal ochre and deep green paint, heavyweight Australian off-road racer"),
("brisbane_neon_rain","neon_gt",829133,"original unbranded low GT coupe street racer, long low nose, tapering two-door cabin, wide rear haunches, tight road tyres, aerodynamic body, glossy midnight graphite and deep blue wet paint, dark glass, restrained cyan and magenta reflected highlights, expensive sleek road racing machine"),
("brisbane_neon_rain","neon_hot_hatch",829151,"original unbranded compact performance hot hatch street racer, short nose, upright squared rear, tight wheelbase, subtle wide arches, small roof spoiler, glossy pearl white graphite and electric blue wet paint, dark panoramic roof, restrained cyan and magenta reflections, slick urban tuner"),
("brisbane_neon_rain","neon_xc90_p2",829177,"early-2000s first-generation P2-era Scandinavian luxury SUV street racer inspired by the 2002 to 2014 Volvo XC90 silhouette, recognizably tall boxy seven-seat wagon SUV proportions, long roof, twin roof rails, broad shoulders, near-vertical tailgate, distinctive tall vertical rear lamp shapes, AWD road stance, slightly lowered, glossy dark graphite wet paint, cyan and magenta city reflections, no manufacturer badge")
]

def submit(skin,vid,seed,desc):
 text=PREFIX+desc
 wf={
 "1":{"class_type":"UNETLoader","inputs":{"unet_name":"massimo-flux-2-klein-4b-fp8.safetensors","weight_dtype":"default"}},
 "2":{"class_type":"CLIPLoader","inputs":{"clip_name":"massimo-qwen_3_4b_fp8.safetensors","type":"flux2","device":"default"}},
 "3":{"class_type":"VAELoader","inputs":{"vae_name":"massimo-flux2-vae.safetensors"}},
 "4":{"class_type":"CLIPTextEncode","inputs":{"text":text,"clip":["2",0]}},
 "5":{"class_type":"FluxGuidance","inputs":{"conditioning":["4",0],"guidance":4.2}},
 "6":{"class_type":"ConditioningZeroOut","inputs":{"conditioning":["4",0]}},
 "7":{"class_type":"ModelSamplingFlux","inputs":{"model":["1",0],"max_shift":1.15,"base_shift":0.5,"width":512,"height":512}},
 "8":{"class_type":"EmptySD3LatentImage","inputs":{"width":512,"height":512,"batch_size":1}},
 "9":{"class_type":"KSampler","inputs":{"seed":seed,"steps":8,"cfg":1.0,"sampler_name":"euler","scheduler":"simple","denoise":1.0,"model":["7",0],"positive":["5",0],"negative":["6",0],"latent_image":["8",0]}},
 "10":{"class_type":"VAEDecode","inputs":{"samples":["9",0],"vae":["3",0]}},
 "11":{"class_type":"SaveImage","inputs":{"filename_prefix":"aps_racer_flux/"+skin+"/"+vid+"/"+vid,"images":["10",0]}}
 }
 req=urllib.request.Request(C+'/prompt',data=json.dumps({"prompt":wf}).encode(),headers={'Content-Type':'application/json'})
 with urllib.request.urlopen(req) as r:return json.load(r)['prompt_id']

def wait(pid):
 for _ in range(300):
  time.sleep(1)
  try:
   with urllib.request.urlopen(C+'/history/'+pid) as r:h=json.load(r)
   if pid in h:
    for node in h[pid].get('outputs',{}).values():
     ims=node.get('images',[])
     if ims:return ims
  except:pass
 raise RuntimeError('timeout '+pid)

for skin,vid,seed,desc in SPECS:
 print('START',skin,vid,flush=True)
 pid=submit(skin,vid,seed,desc)
 for im in wait(pid):
  print('DONE',vid,im.get('subfolder',''),im.get('filename'),flush=True)
print('ALL_DONE',flush=True)
