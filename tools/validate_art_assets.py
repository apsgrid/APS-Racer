#!/usr/bin/env python3
import argparse
import json
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "art" / "asset_manifest.json"
EXPORT = ROOT / "art" / "export"

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def png_info(path: Path):
    with path.open("rb") as f:
        sig = f.read(8)
        if sig != PNG_SIGNATURE:
            raise ValueError("not a PNG file")
        length = struct.unpack(">I", f.read(4))[0]
        chunk = f.read(4)
        if chunk != b"IHDR" or length != 13:
            raise ValueError("invalid PNG IHDR")
        data = f.read(13)
        width, height, bit_depth, colour_type, compression, filtering, interlace = struct.unpack(
            ">IIBBBBB", data
        )
        return {
            "width": width,
            "height": height,
            "bit_depth": bit_depth,
            "colour_type": colour_type,
            "has_alpha": colour_type in (4, 6),
            "rgba": colour_type == 6,
            "interlace": interlace,
        }


def expected_assets(manifest):
    items = []

    for package in manifest["vehicle_packages"]:
        base = EXPORT / "vehicles" / package["skin"] / package["id"]
        for spec in package["files"]:
            filename = f'{package["id"]}_{spec["suffix"]}.{spec["format"]}'
            items.append({
                "path": base / filename,
                "required": bool(spec.get("required", True)),
                "format": spec["format"].lower(),
                "size": tuple(spec["size"]),
                "rgba": bool(spec.get("rgba", False)),
                "id": f'vehicle:{package["id"]}:{spec["suffix"]}',
            })

    for icon in manifest["shared_ui"]["icons"]:
        items.append({
            "path": EXPORT / "shared" / "ui" / icon["filename"],
            "required": True,
            "format": "svg",
            "size": tuple(icon["master"]),
            "rgba": False,
            "id": f'ui:{icon["id"]}',
        })

    for spec in manifest["shared_ui"].get("raster_optional", []):
        items.append({
            "path": EXPORT / "shared" / "ui" / spec["filename"],
            "required": False,
            "format": "png",
            "size": tuple(spec["size"]),
            "rgba": bool(spec.get("rgba", False)),
            "id": f'ui:{spec["id"]}',
        })

    for spec in manifest.get("starter", {}).get("portraits", []):
        items.append({
            "path": EXPORT / "shared" / "starter" / spec["filename"],
            "required": bool(spec.get("required", True)),
            "format": "png",
            "size": tuple(spec["size"]),
            "rgba": bool(spec.get("rgba", True)),
            "id": f'starter:{spec["id"]}',
        })

    for skin_id, skin in manifest["skins"].items():
        base = EXPORT / "skins" / skin_id / "environment"
        for spec in skin["environment"]:
            items.append({
                "path": base / spec["filename"],
                "required": True,
                "format": Path(spec["filename"]).suffix.lower().lstrip("."),
                "size": tuple(spec["size"]),
                "rgba": bool(spec.get("rgba", False)),
                "id": f'{skin_id}:{spec["id"]}',
            })

    return items


def main():
    parser = argparse.ArgumentParser(description="Validate APS Racer production art exports.")
    parser.add_argument(
        "--allow-missing",
        action="store_true",
        help="Report missing assets but do not fail for missing files during pre-production.",
    )
    parser.add_argument(
        "--scaffold",
        action="store_true",
        help="Create the expected runtime export directory tree before validation.",
    )
    args = parser.parse_args()

    if not MANIFEST.exists():
        print(f"ERROR: manifest not found: {MANIFEST}")
        return 2

    try:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8-sig"))
    except Exception as exc:
        print(f"ERROR: invalid manifest: {exc}")
        return 2

    items = expected_assets(manifest)
    if args.scaffold:
        for item in items:
            item["path"].parent.mkdir(parents=True, exist_ok=True)

    seen = set()
    duplicate_paths = []
    for item in items:
        key = str(item["path"]).lower()
        if key in seen:
            duplicate_paths.append(item["path"])
        seen.add(key)

    errors = []
    warnings = []
    missing_required = []
    missing_optional = []
    expected_paths = {item["path"].resolve() for item in items}

    if duplicate_paths:
        errors.extend(f"duplicate manifest path: {p}" for p in duplicate_paths)

    for item in items:
        path = item["path"]
        if not path.exists():
            if item["required"]:
                missing_required.append(item)
            else:
                missing_optional.append(item)
            continue

        if path.suffix.lower().lstrip(".") != item["format"]:
            errors.append(f'{item["id"]}: wrong extension: {path.name}')
            continue

        if item["format"] == "png":
            try:
                info = png_info(path)
            except Exception as exc:
                errors.append(f'{item["id"]}: unreadable PNG: {exc}')
                continue

            actual = (info["width"], info["height"])
            if actual != item["size"]:
                errors.append(
                    f'{item["id"]}: expected {item["size"][0]}x{item["size"][1]}, '
                    f'got {actual[0]}x{actual[1]}'
                )
            if item["rgba"] and not info["rgba"]:
                errors.append(
                    f'{item["id"]}: expected true RGBA PNG (PNG colour type 6), '
                    f'got colour type {info["colour_type"]}'
                )

        elif item["format"] == "svg":
            try:
                head = path.read_text(encoding="utf-8", errors="strict")[:4096]
            except Exception as exc:
                errors.append(f'{item["id"]}: unreadable SVG: {exc}')
                continue
            if "<svg" not in head:
                errors.append(f'{item["id"]}: file does not contain an SVG root')

    if EXPORT.exists():
        known_suffixes = {".png", ".svg"}
        for path in EXPORT.rglob("*"):
            if not path.is_file() or path.suffix.lower() not in known_suffixes:
                continue
            if path.resolve() not in expected_paths:
                warnings.append(f"unknown runtime art file: {path.relative_to(ROOT)}")

    print("APS Racer art validation")
    print(f"Manifest: {MANIFEST.relative_to(ROOT)}")
    print(f"Expected runtime assets: {len(items)}")
    print(f"Present: {sum(1 for i in items if i['path'].exists())}")
    print(f"Missing required: {len(missing_required)}")
    print(f"Missing optional: {len(missing_optional)}")
    print(f"Warnings: {len(warnings)}")
    print(f"Errors: {len(errors)}")

    if missing_required:
        print("\nMissing required:")
        for item in missing_required:
            print(f"  - {item['path'].relative_to(ROOT)}")

    if warnings:
        print("\nWarnings:")
        for warning in warnings:
            print(f"  - {warning}")

    if errors:
        print("\nErrors:")
        for error in errors:
            print(f"  - {error}")

    if errors:
        return 1
    if missing_required and not args.allow_missing:
        return 1

    print("\nRESULT: PASS" + (" (pre-production missing assets allowed)" if args.allow_missing else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
