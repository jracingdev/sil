"""Gera o icone do app S.I.L. (coletor logistico / bipagem)."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "branding"
OUT_DIR.mkdir(parents=True, exist_ok=True)

NAVY = (15, 27, 45, 255)           # fundo escuro industrial
NAVY_SOFT = (26, 40, 64, 255)
AMBER = (255, 196, 25, 255)        # AppColors.accent
AMBER_SOFT = (255, 220, 110, 255)
WHITE = (244, 246, 248, 255)
MUTED = (140, 156, 176, 255)


def _rounded_rect(draw: ImageDraw.ImageDraw, box, radius: int, fill) -> None:
    draw.rounded_rectangle(box, radius=radius, fill=fill)


def _barcode(draw: ImageDraw.ImageDraw, cx: int, cy: int, width: int, height: int) -> None:
    """Barras verticais estilo codigo de barras."""
    pattern = [3, 1, 2, 1, 3, 2, 1, 1, 2, 3, 1, 2, 1, 3, 2, 1, 2, 1, 3, 1, 2]
    total = sum(pattern)
    unit = width / total
    x = cx - width / 2
    top = cy - height / 2
    bottom = cy + height / 2
    for i, w in enumerate(pattern):
        bar_w = max(1, int(round(w * unit)))
        if i % 2 == 0:
            draw.rectangle([int(x), int(top), int(x + bar_w), int(bottom)], fill=WHITE)
        x += w * unit


def _nodes(draw: ImageDraw.ImageDraw, cx: int, y: int, span: int) -> None:
    """Marca S.I.L.: linha com 3 nos (meio amber)."""
    left, mid, right = cx - span // 2, cx, cx + span // 2
    draw.line([(left, y), (right, y)], fill=MUTED, width=max(4, span // 40))
    r_outer = max(10, span // 18)
    r_mid = max(12, span // 15)
    for x, fill, r in (
        (left, WHITE, r_outer),
        (right, WHITE, r_outer),
        (mid, AMBER, r_mid),
    ):
        draw.ellipse([x - r, y - r, x + r, y + r], fill=fill)


def make_full_icon(size: int = 1024) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    pad = int(size * 0.06)
    radius = int(size * 0.22)
    _rounded_rect(draw, [pad, pad, size - pad, size - pad], radius, NAVY)

    # painel interno suave
    inset = int(size * 0.14)
    _rounded_rect(
        draw,
        [inset, inset, size - inset, size - inset],
        int(size * 0.16),
        NAVY_SOFT,
    )

    cx = size // 2
    barcode_cy = int(size * 0.46)
    _barcode(draw, cx, barcode_cy, int(size * 0.52), int(size * 0.28))

    # feixe de leitura (overlay semi com layer)
    beam = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bdraw = ImageDraw.Draw(beam)
    bw = int(size * 0.56)
    by = barcode_cy
    for h, a in ((int(size * 0.05), 55), (int(size * 0.028), 120), (int(size * 0.012), 255)):
        color = (AMBER[0], AMBER[1], AMBER[2], a)
        bdraw.rectangle([cx - bw // 2, by - h // 2, cx + bw // 2, by + h // 2], fill=color)
    img = Image.alpha_composite(img, beam)
    draw = ImageDraw.Draw(img)

    _nodes(draw, cx, int(size * 0.72), int(size * 0.42))
    return img


def make_adaptive_foreground(size: int = 1024) -> Image.Image:
    """Foreground com safe zone (~66% central) para icone adaptativo Android."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx = size // 2
    # conteudo dentro da safe zone
    _barcode(draw, cx, int(size * 0.46), int(size * 0.42), int(size * 0.24))
    beam = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bdraw = ImageDraw.Draw(beam)
    bw = int(size * 0.46)
    by = int(size * 0.46)
    for h, a in ((int(size * 0.045), 55), (int(size * 0.024), 130), (int(size * 0.01), 255)):
        bdraw.rectangle(
            [cx - bw // 2, by - h // 2, cx + bw // 2, by + h // 2],
            fill=(AMBER[0], AMBER[1], AMBER[2], a),
        )
    img = Image.alpha_composite(img, beam)
    draw = ImageDraw.Draw(img)
    _nodes(draw, cx, int(size * 0.68), int(size * 0.34))
    return img


def make_adaptive_background(size: int = 1024) -> Image.Image:
    return Image.new("RGBA", (size, size), NAVY)


def main() -> None:
    full = make_full_icon(1024)
    fg = make_adaptive_foreground(1024)
    bg = make_adaptive_background(1024)

    full_path = OUT_DIR / "app_icon.png"
    fg_path = OUT_DIR / "app_icon_foreground.png"
    bg_path = OUT_DIR / "app_icon_background.png"

    full.save(full_path, "PNG")
    fg.save(fg_path, "PNG")
    bg.save(bg_path, "PNG")
    print(f"OK {full_path}")
    print(f"OK {fg_path}")
    print(f"OK {bg_path}")


if __name__ == "__main__":
    main()
