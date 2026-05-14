#!/usr/bin/env python3
"""Sincroniza a logomarca Valley nos icones dos apps e paineis."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "frontend" / "flutter" / "assets" / "brand" / "logo-valley-launcher.png"
STATUS_PATH = ROOT / "tmp" / "runtime" / "valley-brand-icons-sync.json"

PNG_TARGETS = {
    ROOT / "frontend" / "flutter" / "android" / "app" / "src" / "main" / "res" / "mipmap-mdpi" / "ic_launcher.png": 48,
    ROOT / "frontend" / "flutter" / "android" / "app" / "src" / "main" / "res" / "mipmap-hdpi" / "ic_launcher.png": 72,
    ROOT / "frontend" / "flutter" / "android" / "app" / "src" / "main" / "res" / "mipmap-xhdpi" / "ic_launcher.png": 96,
    ROOT / "frontend" / "flutter" / "android" / "app" / "src" / "main" / "res" / "mipmap-xxhdpi" / "ic_launcher.png": 144,
    ROOT / "frontend" / "flutter" / "android" / "app" / "src" / "main" / "res" / "mipmap-xxxhdpi" / "ic_launcher.png": 192,
    ROOT / "frontend" / "flutter" / "web" / "favicon.png": 32,
    ROOT / "frontend" / "flutter" / "web" / "icons" / "Icon-192.png": 192,
    ROOT / "frontend" / "flutter" / "web" / "icons" / "Icon-maskable-192.png": 192,
    ROOT / "frontend" / "flutter" / "web" / "icons" / "Icon-512.png": 512,
    ROOT / "frontend" / "flutter" / "web" / "icons" / "Icon-maskable-512.png": 512,
}

ICO_TARGETS = [
    ROOT / "admin" / "favicon.ico",
    ROOT / "frontend" / "flutter" / "windows" / "runner" / "resources" / "app_icon.ico",
    ROOT / "tools" / "valley_erp_single_windows" / "app_icon.ico",
]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_source() -> Image.Image:
    if not SOURCE.exists():
        raise FileNotFoundError(f"Logo fonte ausente: {SOURCE}")
    return Image.open(SOURCE).convert("RGBA")


def square_icon(source: Image.Image, size: int) -> Image.Image:
    icon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    source_ratio = source.width / source.height
    target_size = int(size * 0.88)
    if source_ratio >= 1:
        width = target_size
        height = max(1, int(target_size / source_ratio))
    else:
        height = target_size
        width = max(1, int(target_size * source_ratio))
    resized = source.resize((width, height), Image.Resampling.LANCZOS)
    icon.alpha_composite(resized, ((size - width) // 2, (size - height) // 2))
    return icon


def write_png(target: Path, source: Image.Image, size: int) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    square_icon(source, size).save(target, "PNG")


def write_ico(target: Path, source: Image.Image) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    sizes = [16, 24, 32, 48, 64, 128, 256]
    images = [square_icon(source, size) for size in sizes]
    images[-1].save(target, "ICO", sizes=[(size, size) for size in sizes], append_images=images[:-1])


def main() -> int:
    source = load_source()
    touched: list[dict[str, str | int]] = []
    for target, size in PNG_TARGETS.items():
        write_png(target, source, size)
        touched.append({"path": str(target.relative_to(ROOT)), "kind": "png", "size": size, "sha256": sha256(target)})
    for target in ICO_TARGETS:
        write_ico(target, source)
        touched.append({"path": str(target.relative_to(ROOT)), "kind": "ico", "size": 256, "sha256": sha256(target)})

    STATUS_PATH.parent.mkdir(parents=True, exist_ok=True)
    STATUS_PATH.write_text(
        json.dumps(
            {
                "status": "ok",
                "service": "valley-brand-icons-sync",
                "source": str(SOURCE.relative_to(ROOT)),
                "targets_total": len(touched),
                "targets": touched,
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    print(json.dumps({"status": "ok", "targets_total": len(touched)}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
