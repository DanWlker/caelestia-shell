#!/usr/bin/env python3
"""Generate assets/scheme.json: Catppuccin Mocha mapped onto the shell's Material 3 colour roles.

The fork has a fixed theme (no caelestia CLI, no wallpaper-based schemes), so services/Colours.qml
reads this file instead of ~/.local/state/caelestia/scheme.json. Edit the mapping here and rerun:
    python3 scripts/catppuccin-scheme.py
"""

import json
from pathlib import Path

# https://catppuccin.com/palette (Mocha)
MOCHA = {
    "rosewater": "f5e0dc", "flamingo": "f2cdcd", "pink": "f5c2e7", "mauve": "cba6f7",
    "red": "f38ba8", "maroon": "eba0ac", "peach": "fab387", "yellow": "f9e2af",
    "green": "a6e3a1", "teal": "94e2d5", "sky": "89dceb", "sapphire": "74c7ec",
    "blue": "89b4fa", "lavender": "b4befe", "text": "cdd6f4", "subtext1": "bac2de",
    "subtext0": "a6adc8", "overlay2": "9399b2", "overlay1": "7f849c", "overlay0": "6c7086",
    "surface2": "585b70", "surface1": "45475a", "surface0": "313244", "base": "1e1e2e",
    "mantle": "181825", "crust": "11111b",
}


def mix(a: str, b: str, t: float) -> str:
    """Blend colour a towards b by t (0 = a, 1 = b)."""
    ca = [int(a[i : i + 2], 16) for i in (0, 2, 4)]
    cb = [int(b[i : i + 2], 16) for i in (0, 2, 4)]
    return "".join(f"{round(x + (y - x) * t):02x}" for x, y in zip(ca, cb))


def accent(name: str, colour: str) -> dict[str, str]:
    """M3 accent group: the colour itself, dark text on it, and a dimmed container."""
    return {
        name: colour,
        f"on{name.capitalize()}": MOCHA["crust"],
        f"{name}Container": mix(colour, MOCHA["base"], 0.65),
        f"on{name.capitalize()}Container": mix(colour, MOCHA["text"], 0.5),
    }


def fixed(name: str, colour: str) -> dict[str, str]:
    return {
        f"{name}Fixed": mix(colour, "ffffff", 0.3),
        f"{name}FixedDim": colour,
        f"on{name.capitalize()}Fixed": MOCHA["crust"],
        f"on{name.capitalize()}FixedVariant": mix(colour, MOCHA["base"], 0.65),
    }


c = MOCHA
primary, secondary, tertiary = c["lavender"], c["blue"], c["mauve"]

colours = {
    "primary_paletteKeyColor": primary,
    "secondary_paletteKeyColor": secondary,
    "tertiary_paletteKeyColor": tertiary,
    "neutral_paletteKeyColor": c["overlay1"],
    "neutral_variant_paletteKeyColor": c["overlay0"],
    # Surfaces: base is the panel colour, containers step up towards surface1
    "background": c["base"],
    "onBackground": c["text"],
    "surface": c["base"],
    "surfaceDim": c["mantle"],
    "surfaceBright": c["surface1"],
    "surfaceContainerLowest": c["crust"],
    "surfaceContainerLow": c["mantle"],
    "surfaceContainer": mix(c["base"], c["surface0"], 0.5),
    "surfaceContainerHigh": c["surface0"],
    "surfaceContainerHighest": mix(c["surface0"], c["surface1"], 0.5),
    "onSurface": c["text"],
    "surfaceVariant": c["surface1"],
    "onSurfaceVariant": c["subtext0"],
    "inverseSurface": c["text"],
    "inverseOnSurface": c["base"],
    "outline": c["overlay0"],
    "outlineVariant": c["surface1"],
    "shadow": "000000",
    "scrim": "000000",
    "surfaceTint": primary,
    "inversePrimary": mix(primary, c["crust"], 0.5),
    **accent("primary", primary),
    **accent("secondary", secondary),
    **accent("tertiary", tertiary),
    **accent("error", c["red"]),
    **accent("success", c["green"]),
    **fixed("primary", primary),
    **fixed("secondary", secondary),
    **fixed("tertiary", tertiary),
    # Terminal colours, as in Catppuccin's own terminal ports
    **{
        f"term{i}": c[n]
        for i, n in enumerate(
            ["surface1", "red", "green", "yellow", "blue", "pink", "teal", "subtext1",
             "surface2", "red", "green", "yellow", "blue", "pink", "teal", "subtext0"]
        )
    },
    # The named palette too, for anything that wants a Catppuccin colour directly
    **c,
}

scheme = {"name": "catppuccin", "flavour": "mocha", "mode": "dark", "variant": "tonalspot", "colours": colours}
out = Path(__file__).resolve().parent.parent / "assets" / "scheme.json"
out.write_text(json.dumps(scheme, indent=4) + "\n")
print(f"Wrote {out}")
