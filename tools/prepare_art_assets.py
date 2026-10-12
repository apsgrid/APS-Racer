import json, math, os, random, shutil
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

ROOT=Path(r"F:\Projects\APS-Racer")
MANIFEST=ROOT/"art"/"asset_manifest.json"
EXPORT=ROOT/"art"/"export"
COMFY_OUT=Path(r"C:\ComfyUI-ROCm\output\aps_racer_flux")
random.seed(6060)

VEHICLES=[
 ("red_dirt","desert_prerunner"),
 ("red_dirt","baja_compact"),
 ("red_dirt","monster_4x4"),
 ("brisbane_neon_rain","neon_gt"),
 ("brisbane_neon_rain","neon_hot_hatch"),
 ("brisbane_neon_rain","neon_xc90_p2"),
]

def latest_source(skin, vid):
    folder=COMFY_OUT/skin
    files=sorted(folder.rglob(vid+"*.png"), key=lambda p:p.stat().st_mtime)
    return files[-1] if files else None

def remove_green(im):
    im=im.convert("RGBA")
    px=im.load(); w,h=im.size
    corners=[]
    for y in list(range(0,min(80,h),8))+list(range(max(0,h-80),h,8)):
        for x in list(range(0,min(80,w),8))+list(range(max(0,w-80),w,8)):
            corners.append(px[x,y][:3])
    bg=tuple(sorted(v[i] for v in corners)[len(corners)//2] for i in range(3))
    out=Image.new("RGBA", im.size)
    op=out.load()
    for y in range(h):
        for x in range(w):
            r,g,b,a=px[x,y]
            dist=((r-bg[0])**2+(g-bg[1])**2+(b-bg[2])**2)**0.5
            green_dom=g-max(r,b)
            if dist < 38 or (green_dom>38 and g>105 and dist<125):
                alpha=0
            elif dist < 78 and green_dom>12:
                alpha=int(max(0,min(255,(dist-38)/40*255)))
            else:
                alpha=a
            op[x,y]=(r,g,b,alpha)
    # remove edge-connected residuals by a light alpha erosion
    alpha=out.getchannel("A").filter(ImageFilter.MedianFilter(3))
    out.putalpha(alpha)

    # Chroma defringe: suppress residual green only on semi-transparent/edge pixels.
    px2=out.load()
    for yy in range(h):
        for xx in range(w):
            r,g,b,a=px2[xx,yy]
            if a>0 and g-max(r,b)>24 and (a<250 or g>175):
                g=max(r,b)
                px2[xx,yy]=(r,g,b,a)
    return out

def normalize_vehicle(im):
    a=im.getchannel("A")
    bbox=a.getbbox()
    if not bbox:
        return Image.new("RGBA",(1024,1024),(0,0,0,0))
    crop=im.crop(bbox)
    maxdim=835
    scale=float(maxdim)/float(max(crop.width,crop.height))
    crop=crop.resize(
        (max(1,int(round(crop.width*scale))),max(1,int(round(crop.height*scale)))),
        Image.Resampling.LANCZOS
    )
    canvas=Image.new("RGBA",(1024,1024),(0,0,0,0))
    x=(1024-crop.width)//2
    y=(1024-crop.height)//2
    canvas.alpha_composite(crop,(x,y))
    return canvas

def save_vehicle_layers(skin,vid):
    src=latest_source(skin,vid)
    if src is None:
        print("MISSING_SOURCE",skin,vid); return False
    dst=EXPORT/"vehicles"/skin/vid
    dst.mkdir(parents=True,exist_ok=True)
    comp=normalize_vehicle(remove_green(Image.open(src)))
    if vid in {"baja_compact","monster_4x4","neon_gt","neon_hot_hatch"}:
        comp=comp.rotate(180)
    comp.save(dst/f"{vid}_composite.png")
    comp.save(dst/f"{vid}_body.png")
    Image.new("RGBA",(1024,1024),(0,0,0,0)).save(dst/f"{vid}_glass.png")
    # shadow from alpha, softened and offset
    alpha=comp.getchannel("A").filter(ImageFilter.GaussianBlur(18))
    sh=Image.new("RGBA",(1024,1024),(15,12,12,0))
    sh.putalpha(alpha.point(lambda v:int(v*0.34)))
    sh.save(dst/f"{vid}_shadow.png")
    # generic wheel sprites
    for kind in ("front_wheel","rear_wheel"):
        wi=Image.new("RGBA",(256,256),(0,0,0,0))
        d=ImageDraw.Draw(wi)
        d.rounded_rectangle((82,26,174,230),radius=28,fill=(13,14,16,255),outline=(62,64,66,255),width=5)
        for yy in range(46,220,24):
            d.line((89,yy,167,yy+8),fill=(88,88,82,210),width=4)
        wi.save(dst/f"{vid}_{kind}.png")
    # emission layers
    hi=Image.new("RGBA",(1024,1024),(0,0,0,0)); d=ImageDraw.Draw(hi)
    d.ellipse((325,90,430,150),fill=(245,250,255,180)); d.ellipse((594,90,699,150),fill=(245,250,255,180))
    hi=hi.filter(ImageFilter.GaussianBlur(5)); hi.save(dst/f"{vid}_headlights.png")
    br=Image.new("RGBA",(1024,1024),(0,0,0,0)); d=ImageDraw.Draw(br)
    d.ellipse((325,874,430,925),fill=(255,45,35,190)); d.ellipse((594,874,699,925),fill=(255,45,35,190))
    br=br.filter(ImageFilter.GaussianBlur(4)); br.save(dst/f"{vid}_brakelights.png")
    overlay=Image.new("RGBA",(1024,1024),(0,0,0,0))
    suffix="dirt_overlay" if skin=="red_dirt" else "wet_neon_overlay"
    overlay.save(dst/f"{vid}_{suffix}.png")
    print("VEHICLE_READY",skin,vid,src)
    return True

def noisy_tile(size, base, variance, seed, streak=False):
    rnd=random.Random(seed)
    w,h=size
    img=Image.new("RGBA",size,(*base,255)); p=img.load()
    for y in range(h):
        for x in range(w):
            n=rnd.randint(-variance,variance)
            p[x,y]=(max(0,min(255,base[0]+n)),max(0,min(255,base[1]+n)),max(0,min(255,base[2]+n)),255)
    if streak:
        d=ImageDraw.Draw(img,"RGBA")
        for _ in range(45):
            y=rnd.randrange(h); x=rnd.randrange(w)
            d.line((x,y,min(w,x+rnd.randrange(80,280)),y+rnd.randrange(-8,9)),fill=(255,255,255,rnd.randrange(6,20)),width=rnd.randrange(1,4))
    return img.filter(ImageFilter.GaussianBlur(0.35))

def prop_canvas(size):
    return Image.new("RGBA",size,(0,0,0,0))

def red_asset(spec):
    size=tuple(spec["size"]); id=spec["id"]
    if id=="surface_packed": return noisy_tile(size,(165,74,44),24,10,True)
    if id=="surface_loose": return noisy_tile(size,(181,92,58),34,11,True)
    if id=="rut_overlay":
        im=prop_canvas(size); d=ImageDraw.Draw(im,"RGBA")
        for off in (-95,95):
            pts=[(0,size[1]*.5+off),(size[0]*.25,size[1]*.47+off),(size[0]*.52,size[1]*.54+off),(size[0],size[1]*.49+off)]
            d.line(pts,fill=(74,39,26,100),width=32)
            d.line(pts,fill=(230,145,95,32),width=5)
        return im
    im=prop_canvas(size); d=ImageDraw.Draw(im,"RGBA"); w,h=size
    if id.startswith("scrub"):
        for i in range(16):
            cx=w*.5+random.randint(-w//5,w//5); cy=h*.55+random.randint(-h//6,h//6)
            r=random.randint(max(3,w//22),max(5,w//10)); d.ellipse((cx-r,cy-r,cx+r,cy+r),fill=(91,92,48,210))
            d.line((w*.5,h*.8,cx,cy),fill=(88,58,32,170),width=max(1,w//70))
    elif id.startswith("rock"):
        for i in range(7):
            cx=random.randint(w//4,3*w//4); cy=random.randint(h//3,3*h//4); r=random.randint(max(4,w//12),max(6,w//6))
            col=random.choice([(104,77,60,255),(129,92,67,255),(91,68,58,255)])
            d.polygon([(cx-r,cy),(cx-r//2,cy-r),(cx+r//2,cy-r//2),(cx+r,cy+r//3),(cx,cy+r)],fill=col)
    elif id=="fence_post":
        d.rectangle((w*.43,h*.08,w*.57,h*.92),fill=(91,65,43,255)); d.rectangle((w*.46,h*.08,w*.50,h*.92),fill=(170,115,70,120))
    elif id=="corrugated_fence":
        d.rectangle((20,h*.25,w-20,h*.78),fill=(113,91,74,255)); 
        for x in range(22,w-20,18): d.line((x,h*.27,x,h*.76),fill=(177,147,118,120),width=4)
    elif id in ("tyre_stack","steel_barrier"):
        if id=="tyre_stack":
            for x in range(25,w-25,55):
                d.ellipse((x,h*.32,x+50,h*.68),fill=(18,18,18,255),outline=(70,70,65,255),width=4)
        else:
            d.rounded_rectangle((15,h*.33,w-15,h*.72),radius=12,fill=(120,111,102,255),outline=(211,165,124,255),width=5)
    elif id=="event_cone":
        d.polygon([(w*.5,h*.12),(w*.25,h*.8),(w*.75,h*.8)],fill=(238,95,35,255)); d.rectangle((w*.2,h*.78,w*.8,h*.9),fill=(72,45,35,255)); d.rectangle((w*.34,h*.52,w*.66,h*.62),fill=(238,224,190,255))
    elif id=="barrel":
        d.ellipse((w*.22,h*.12,w*.78,h*.35),fill=(154,74,45,255)); d.rectangle((w*.22,h*.23,w*.78,h*.8),fill=(144,66,42,255)); d.ellipse((w*.22,h*.68,w*.78,h*.88),fill=(108,52,38,255))
    elif id=="shed":
        d.rectangle((w*.18,h*.38,w*.82,h*.82),fill=(105,73,53,255)); d.polygon([(w*.12,h*.4),(w*.5,h*.16),(w*.88,h*.4)],fill=(91,71,58,255))
        for x in range(int(w*.2),int(w*.82),max(5,w//18)): d.line((x,h*.4,x,h*.82),fill=(157,118,87,85),width=3)
    elif id=="telegraph_pole":
        d.rectangle((w*.47,h*.1,w*.53,h*.9),fill=(72,50,32,255)); d.rectangle((w*.25,h*.24,w*.75,h*.3),fill=(82,57,37,255))
    elif id=="event_sign":
        d.rounded_rectangle((w*.1,h*.3,w*.9,h*.72),radius=8,fill=(80,47,30,255),outline=(225,142,64,255),width=5)
        d.polygon([(w*.25,h*.51),(w*.42,h*.4),(w*.42,h*.47),(w*.72,h*.47),(w*.72,h*.55),(w*.42,h*.55),(w*.42,h*.62)],fill=(240,180,72,255))
    elif id=="start_finish":
        for x in range(0,w,32):
            d.rectangle((x,0,x+32,h),fill=((242,224,195,255) if (x//32)%2==0 else (57,33,25,255)))
    elif id=="checkpoint":
        d.ellipse((w*.2,h*.2,w*.8,h*.8),outline=(242,138,66,220),width=max(4,w//30)); d.ellipse((w*.34,h*.34,w*.66,h*.66),outline=(244,198,110,120),width=max(2,w//50))
    elif id.startswith("dust"):
        for i in range(35):
            r=random.randint(max(4,w//20),max(8,w//7)); cx=random.randint(0,w); cy=random.randint(h//3,h); d.ellipse((cx-r,cy-r,cx+r,cy+r),fill=(210,145,95,random.randint(20,75)))
        im=im.filter(ImageFilter.GaussianBlur(max(2,w//80)))
    return im

def neon_asset(spec):
    size=tuple(spec["size"]); id=spec["id"]; w,h=size
    if id=="surface_wet": return noisy_tile(size,(18,25,35),13,20,True)
    if id=="surface_dark_wet": return noisy_tile(size,(9,13,20),10,21,True)
    im=prop_canvas(size); d=ImageDraw.Draw(im,"RGBA")
    if id.startswith("reflection"):
        col=(52,216,255,90) if "cyan" in id else (255,62,191,90)
        for i in range(9):
            x=random.randint(0,w); d.rectangle((x,0,x+random.randint(20,80),h),fill=col)
        im=im.filter(ImageFilter.GaussianBlur(max(8,w//35)))
    elif id.startswith("puddle"):
        for i in range(4):
            cx=random.randint(w//4,3*w//4); cy=random.randint(h//4,3*h//4); rx=random.randint(w//8,w//3); ry=random.randint(h//18,h//8)
            d.ellipse((cx-rx,cy-ry,cx+rx,cy+ry),fill=(120,180,215,25),outline=(180,235,255,65),width=2)
    elif id=="lane_solid": d.rectangle((0,h*.42,w,h*.58),fill=(225,230,235,230))
    elif id=="lane_broken":
        for x in range(0,w,180): d.rectangle((x,h*.42,min(w,x+95),h*.58),fill=(225,230,235,220))
    elif id=="road_stud":
        d.rounded_rectangle((w*.25,h*.36,w*.75,h*.64),radius=8,fill=(55,60,66,255),outline=(180,235,255,220),width=4); d.ellipse((w*.4,h*.43,w*.6,h*.57),fill=(70,220,255,240))
    elif id in ("neon_barrier","concrete_barrier"):
        d.rounded_rectangle((15,h*.33,w-15,h*.72),radius=10,fill=(56,61,72,255),outline=(110,125,140,255),width=4)
        if id=="neon_barrier":
            d.rectangle((22,h*.42,w-22,h*.52),fill=(52,216,255,230)); d.rectangle((22,h*.56,w-22,h*.63),fill=(255,62,191,210))
    elif id=="railing":
        d.line((10,h*.72,w-10,h*.72),fill=(95,110,125,255),width=7)
        for x in range(15,w-15,32): d.line((x,h*.3,x,h*.72),fill=(90,105,120,255),width=4)
    elif id=="bollard":
        d.rounded_rectangle((w*.38,h*.16,w*.62,h*.88),radius=10,fill=(35,42,52,255),outline=(95,110,125,255),width=4); d.rectangle((w*.39,h*.38,w*.61,h*.5),fill=(255,62,191,220))
    elif id=="light_pole":
        d.rectangle((w*.48,h*.18,w*.53,h*.88),fill=(72,80,90,255)); d.ellipse((w*.3,h*.08,w*.72,h*.3),fill=(175,225,255,80),outline=(220,245,255,220),width=4)
    elif id=="billboard":
        d.rounded_rectangle((w*.08,h*.22,w*.92,h*.76),radius=12,fill=(10,14,24,255),outline=(52,216,255,255),width=5); d.line((w*.18,h*.5,w*.82,h*.5),fill=(255,62,191,210),width=10)
    elif id.startswith("city_block"):
        d.rectangle((w*.12,h*.18,w*.88,h*.86),fill=(12,16,26,255),outline=(60,70,86,255),width=4)
        for yy in range(int(h*.28),int(h*.78),max(15,h//10)):
            for xx in range(int(w*.22),int(w*.8),max(18,w//8)):
                col=random.choice([(52,216,255,110),(255,62,191,100),(220,235,255,55)])
                d.rectangle((xx,yy,xx+w//18,yy+h//22),fill=col)
    elif id=="drain":
        d.rounded_rectangle((8,h*.22,w-8,h*.78),radius=8,fill=(35,39,46,255),outline=(100,112,126,255),width=4)
        for x in range(20,w-20,22): d.line((x,h*.3,x,h*.7),fill=(10,12,16,255),width=5)
    elif id=="start_finish":
        for x in range(0,w,32):
            d.rectangle((x,0,x+32,h),fill=((52,216,255,255) if (x//32)%2==0 else (255,62,191,255)))
    elif id=="checkpoint":
        d.ellipse((w*.18,h*.18,w*.82,h*.82),outline=(52,216,255,220),width=max(4,w//28)); d.arc((w*.26,h*.26,w*.74,h*.74),30,210,fill=(255,62,191,240),width=max(3,w//34))
    elif id.startswith("spray") or id=="splash":
        for i in range(50):
            x=random.randint(w//6,5*w//6); y=random.randint(h//3,5*h//6); rr=random.randint(2,max(3,w//35))
            d.ellipse((x-rr,y-rr,x+rr,y+rr),fill=(170,225,255,random.randint(25,110)))
        im=im.filter(ImageFilter.GaussianBlur(max(1,w//120)))
    return im

def make_icons(manifest):
    out=EXPORT/"shared"/"ui"; out.mkdir(parents=True,exist_ok=True)
    shapes={
      "skin":'<circle cx="64" cy="64" r="32"/><circle cx="48" cy="50" r="5"/><circle cx="75" cy="44" r="5"/><circle cx="82" cy="70" r="5"/>',
      "course":'<path d="M18 64 C18 25 45 24 64 52 C83 24 110 25 110 64 C110 103 83 104 64 76 C45 104 18 103 18 64Z"/>',
      "data":'<path d="M24 96V62M48 96V38M72 96V50M96 96V24"/>',
      "tune":'<path d="M30 86L82 34M72 25L103 56M24 91L37 104"/>',
      "car":'<path d="M22 78L30 50L42 38H86L98 50L106 78V94H94V84H34V94H22Z"/><circle cx="38" cy="76" r="7"/><circle cx="90" cy="76" r="7"/>',
      "reset":'<path d="M96 48A40 40 0 1 0 100 82"/><path d="M96 24V50H70"/>',
      "save":'<path d="M24 22H96V106H24Z"/><path d="M40 22V50H82V22M40 74H82V106H40Z"/>',
      "load":'<path d="M64 18V78M40 56L64 80L88 56M26 92H102"/>',
      "delete":'<path d="M34 38H94M46 38V28H82V38M42 44L48 102H80L86 44"/>',
      "bake":'<path d="M32 26H96V96H32Z"/><path d="M44 48H84M44 64H84M44 80H72"/>',
      "copy":'<rect x="38" y="28" width="58" height="70"/><rect x="24" y="42" width="58" height="70"/>',
      "close":'<path d="M28 28L100 100M100 28L28 100"/>',
      "left":'<path d="M82 24L40 64L82 104"/>',
      "right":'<path d="M46 24L88 64L46 104"/>',
      "throttle":'<path d="M34 98L48 30H80L94 98Z"/><circle cx="64" cy="72" r="12"/>',
      "brake":'<rect x="28" y="42" width="72" height="50" rx="10"/><path d="M42 58H86M42 74H86"/>',
      "handbrake":'<path d="M28 92L88 32M78 24L100 46M24 98L38 108"/>',
      "ghost":'<path d="M28 102V58A36 36 0 0 1 100 58V102L88 90L76 102L64 90L52 102L40 90Z"/><circle cx="50" cy="58" r="5"/><circle cx="78" cy="58" r="5"/>',
      "rival":'<path d="M64 18L106 104H22Z"/><circle cx="64" cy="74" r="10"/>',
      "best_lap":'<circle cx="64" cy="64" r="42"/><path d="M64 36V66L82 78"/>',
      "sector":'<path d="M24 96V30H104L88 48L104 66H24"/>'
    }
    for icon in manifest["shared_ui"]["icons"]:
        id=icon["id"]; body=shapes.get(id,'<circle cx="64" cy="64" r="30"/>')
        svg=f'''<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><g fill="none" stroke="#ffffff" stroke-width="8" stroke-linecap="round" stroke-linejoin="round">{body}</g></svg>'''
        (out/icon["filename"]).write_text(svg,encoding="utf-8")

def make_environment(manifest):
    for skin, data in manifest["skins"].items():
        out=EXPORT/"skins"/skin/"environment"; out.mkdir(parents=True,exist_ok=True)
        for spec in data["environment"]:
            img=red_asset(spec) if skin=="red_dirt" else neon_asset(spec)
            img.convert("RGBA").save(out/spec["filename"])

def main():
    manifest=json.loads(MANIFEST.read_text(encoding="utf-8-sig"))
    make_icons(manifest)
    make_environment(manifest)
    ready=0
    for skin,vid in VEHICLES:
        if save_vehicle_layers(skin,vid): ready+=1
    print("ASSETS_DONE vehicles",ready,"of",len(VEHICLES))

if __name__=="__main__":
    main()
