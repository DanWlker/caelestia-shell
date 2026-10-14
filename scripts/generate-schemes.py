#!/usr/bin/env python3
"""Generate assets/schemes/<name>/<flavour>.json: popular themes mapped onto the shell's Material 3 colour roles.

The fork has no caelestia CLI and no wallpaper-based schemes. These are the bundled schemes the launcher's
scheme picker (>scheme) lists, alongside any in paths.schemeDir; catppuccin/mocha is also the fallback before
a scheme has been picked. Palettes are the themes' official ones (sources next to each). Each theme fills the
same slots (a Catppuccin-style ramp from crust to text, five accents and 16 terminal colours), and scheme()
maps the slots to roles. Edit and rerun (stale files in assets/schemes are removed):
    python3 scripts/generate-schemes.py
"""

import json
from pathlib import Path


def mix(a: str, b: str, t: float) -> str:
    """Blend colour a towards b by t (0 = a, 1 = b)."""
    ca = [int(a[i : i + 2], 16) for i in (0, 2, 4)]
    cb = [int(b[i : i + 2], 16) for i in (0, 2, 4)]
    return "".join(f"{round(x + (y - x) * t):02x}" for x, y in zip(ca, cb))


def ansi(black, red, green, yellow, blue, magenta, cyan, white, bright_black, bright_white, brights=None):
    """16 terminal colours; the bright accents repeat the normal ones unless given."""
    accents = [red, green, yellow, blue, magenta, cyan]
    return [black, *accents, white, bright_black, *(brights or accents), bright_white]


def scheme(name: str, flavour: str, s: dict) -> dict:
    """Map a theme's slots onto M3 roles.

    Slots: mode, crust, mantle, base, surface0, surface1, overlay0, overlay1, subtext0, text, primary,
    secondary, tertiary, red, green, term. Dark themes: crust and mantle are darker than base, surfaces lighter.
    Light themes: mantle, crust and surface0 get darker step by step.
    """
    light = s["mode"] == "light"
    on_accent = s["base"] if light else s["crust"]

    def accent(role: str, colour: str) -> dict[str, str]:
        """M3 accent group: the colour itself, text on it, and a dimmed container."""
        return {
            role: colour,
            f"on{role.capitalize()}": on_accent,
            f"{role}Container": mix(colour, s["base"], 0.65),
            f"on{role.capitalize()}Container": mix(colour, s["text"], 0.5),
        }

    def fixed(role: str, colour: str) -> dict[str, str]:
        return {
            f"{role}Fixed": mix(colour, "ffffff", 0.3),
            f"{role}FixedDim": colour,
            f"on{role.capitalize()}Fixed": s["text"] if light else s["crust"],
            f"on{role.capitalize()}FixedVariant": mix(colour, s["base"], 0.65),
        }

    if light:
        # Base is the panel colour, containers step down towards surface0
        surfaces = {
            "surfaceDim": s["crust"],
            "surfaceBright": mix(s["base"], "ffffff", 0.5),
            "surfaceContainerLowest": mix(s["base"], "ffffff", 0.5),
            "surfaceContainerLow": s["base"],
            "surfaceContainer": s["mantle"],
            "surfaceContainerHigh": s["crust"],
            "surfaceContainerHighest": mix(s["crust"], s["surface0"], 0.5),
        }
    else:
        # Base is the panel colour, containers step up towards surface1
        surfaces = {
            "surfaceDim": s["mantle"],
            "surfaceBright": s["surface1"],
            "surfaceContainerLowest": s["crust"],
            "surfaceContainerLow": s["mantle"],
            "surfaceContainer": mix(s["base"], s["surface0"], 0.5),
            "surfaceContainerHigh": s["surface0"],
            "surfaceContainerHighest": mix(s["surface0"], s["surface1"], 0.5),
        }

    colours = {
        "primary_paletteKeyColor": s["primary"],
        "secondary_paletteKeyColor": s["secondary"],
        "tertiary_paletteKeyColor": s["tertiary"],
        "neutral_paletteKeyColor": s["overlay1"],
        "neutral_variant_paletteKeyColor": s["overlay0"],
        "background": s["base"],
        "onBackground": s["text"],
        "surface": s["base"],
        **surfaces,
        "onSurface": s["text"],
        "surfaceVariant": s["surface1"],
        "onSurfaceVariant": s["subtext0"],
        "inverseSurface": s["text"],
        "inverseOnSurface": s["base"],
        "outline": s["overlay0"],
        "outlineVariant": s["surface1"],
        "shadow": "000000",
        "scrim": "000000",
        "surfaceTint": s["primary"],
        "inversePrimary": mix(s["primary"], s["crust"], 0.5),
        **accent("primary", s["primary"]),
        **accent("secondary", s["secondary"]),
        **accent("tertiary", s["tertiary"]),
        **accent("error", s["red"]),
        **accent("success", s["green"]),
        **fixed("primary", s["primary"]),
        **fixed("secondary", s["secondary"]),
        **fixed("tertiary", s["tertiary"]),
        **{f"term{i}": c for i, c in enumerate(s["term"])},
    }
    return {"name": name, "flavour": flavour, "mode": s["mode"], "colours": colours}


SCHEMES: dict[str, dict[str, dict]] = {}

# --- Catppuccin: https://catppuccin.com/palette ---------------------------------------------------------------
CATPPUCCIN = {
    "latte": {
        "rosewater": "dc8a78", "flamingo": "dd7878", "pink": "ea76cb", "mauve": "8839ef",
        "red": "d20f39", "maroon": "e64553", "peach": "fe640b", "yellow": "df8e1d",
        "green": "40a02b", "teal": "179299", "sky": "04a5e5", "sapphire": "209fb5",
        "blue": "1e66f5", "lavender": "7287fd", "text": "4c4f69", "subtext1": "5c5f77",
        "subtext0": "6c6f85", "overlay2": "7c7f93", "overlay1": "8c8fa1", "overlay0": "9ca0b0",
        "surface2": "acb0be", "surface1": "bcc0cc", "surface0": "ccd0da", "base": "eff1f5",
        "mantle": "e6e9ef", "crust": "dce0e8",
    },
    "frappe": {
        "rosewater": "f2d5cf", "flamingo": "eebebe", "pink": "f4b8e4", "mauve": "ca9ee6",
        "red": "e78284", "maroon": "ea999c", "peach": "ef9f76", "yellow": "e5c890",
        "green": "a6d189", "teal": "81c8be", "sky": "99d1db", "sapphire": "85c1dc",
        "blue": "8caaee", "lavender": "babbf1", "text": "c6d0f5", "subtext1": "b5bfe2",
        "subtext0": "a5adce", "overlay2": "949cbb", "overlay1": "838ba7", "overlay0": "737994",
        "surface2": "626880", "surface1": "51576d", "surface0": "414559", "base": "303446",
        "mantle": "292c3c", "crust": "232634",
    },
    "macchiato": {
        "rosewater": "f4dbd6", "flamingo": "f0c6c6", "pink": "f5bde6", "mauve": "c6a0f6",
        "red": "ed8796", "maroon": "ee99a0", "peach": "f5a97f", "yellow": "eed49f",
        "green": "a6da95", "teal": "8bd5ca", "sky": "91d7e3", "sapphire": "7dc4e4",
        "blue": "8aadf4", "lavender": "b7bdf8", "text": "cad3f5", "subtext1": "b8c0e0",
        "subtext0": "a5adcb", "overlay2": "939ab7", "overlay1": "8087a2", "overlay0": "6e738d",
        "surface2": "5b6078", "surface1": "494d64", "surface0": "363a4f", "base": "24273a",
        "mantle": "1e2030", "crust": "181926",
    },
    "mocha": {
        "rosewater": "f5e0dc", "flamingo": "f2cdcd", "pink": "f5c2e7", "mauve": "cba6f7",
        "red": "f38ba8", "maroon": "eba0ac", "peach": "fab387", "yellow": "f9e2af",
        "green": "a6e3a1", "teal": "94e2d5", "sky": "89dceb", "sapphire": "74c7ec",
        "blue": "89b4fa", "lavender": "b4befe", "text": "cdd6f4", "subtext1": "bac2de",
        "subtext0": "a6adc8", "overlay2": "9399b2", "overlay1": "7f849c", "overlay0": "6c7086",
        "surface2": "585b70", "surface1": "45475a", "surface0": "313244", "base": "1e1e2e",
        "mantle": "181825", "crust": "11111b",
    },
}
for flavour, c in CATPPUCCIN.items():
    light = flavour == "latte"
    # Terminal colours as in Catppuccin's own terminal ports
    term = ansi(c["subtext1"] if light else c["surface1"], c["red"], c["green"], c["yellow"], c["blue"], c["pink"],
                c["teal"], c["surface2"] if light else c["subtext1"], c["subtext0"] if light else c["surface2"],
                c["surface1"] if light else c["subtext0"])
    SCHEMES.setdefault("catppuccin", {})[flavour] = {
        **{k: c[k] for k in ("crust", "mantle", "base", "surface0", "surface1", "overlay0", "overlay1", "subtext0",
                             "text", "red", "green")},
        "mode": "light" if light else "dark",
        "primary": c["lavender"], "secondary": c["blue"], "tertiary": c["mauve"],
        "term": term,
    }

# --- Dracula: https://spec.draculatheme.com ---------------------------------------------------------------------
SCHEMES["dracula"] = {"default": {
    "mode": "dark", "crust": "191a21", "mantle": "21222c", "base": "282a36",
    "surface0": mix("282a36", "44475a", 0.5), "surface1": "44475a",
    "overlay0": "6272a4", "overlay1": mix("6272a4", "f8f8f2", 0.3), "subtext0": mix("f8f8f2", "6272a4", 0.25),
    "text": "f8f8f2", "primary": "bd93f9", "secondary": "ff79c6", "tertiary": "8be9fd",
    "red": "ff5555", "green": "50fa7b",
    "term": ansi("21222c", "ff5555", "50fa7b", "f1fa8c", "bd93f9", "ff79c6", "8be9fd", "f8f8f2", "6272a4", "ffffff",
                 ["ff6e6e", "69ff94", "ffffa5", "d6acff", "ff92df", "a4ffff"]),
}}

# --- Everblush: github.com/Everblush/everblush.nvim (lua/everblush/palette.lua) -----------------------------------
SCHEMES["everblush"] = {"default": {
    "mode": "dark", "crust": mix("141b1e", "000000", 0.3), "mantle": mix("141b1e", "000000", 0.15), "base": "141b1e",
    "surface0": "232a2d", "surface1": "2d3437",
    "overlay0": mix("404749", "b3b9b8", 0.3), "overlay1": mix("404749", "b3b9b8", 0.5), "subtext0": "b3b9b8",
    "text": "dadada", "primary": "67b0e8", "secondary": "c47fd5", "tertiary": "6cbfbf",
    "red": "e57474", "green": "8ccf7e",
    "term": ansi("232a2d", "e57474", "8ccf7e", "e5c76b", "67b0e8", "c47fd5", "6cbfbf", "b3b9b8", "2d3437", "bdc3c2",
                 ["ef7e7e", "96d988", "f4d67a", "71baf2", "ce89df", "67cbe7"]),
}}

# --- Everforest: github.com/sainnhe/everforest (autoload/everforest.vim) ------------------------------------------
EVERFOREST_BG = {  # bg_dim, bg0, bg1, bg2, bg3, bg4, bg5
    ("dark", "hard"): ["1e2326", "272e33", "2e383c", "374145", "414b50", "495156", "4f5b58"],
    ("dark", "medium"): ["232a2e", "2d353b", "343f44", "3d484d", "475258", "4f585e", "56635f"],
    ("dark", "soft"): ["293136", "333c43", "3a464c", "434f55", "4d5960", "555f66", "5d6b66"],
    ("light", "hard"): ["f2efdf", "fffbef", "f8f5e4", "f2efdf", "edeada", "e8e5d5", "bec5b2"],
    ("light", "medium"): ["efebd4", "fdf6e3", "f4f0d9", "efebd4", "e6e2cc", "e0dcc7", "bdc3af"],
    ("light", "soft"): ["e5dfc5", "f3ead3", "eae4ca", "e5dfc5", "ddd8be", "d8d3ba", "b9c0ab"],
}
EVERFOREST_FG = {
    "dark": {"fg": "d3c6aa", "red": "e67e80", "orange": "e69875", "yellow": "dbbc7f", "green": "a7c080",
             "aqua": "83c092", "blue": "7fbbb3", "purple": "d699b6", "grey0": "7a8478", "grey1": "859289",
             "grey2": "9da9a0"},
    "light": {"fg": "5c6a72", "red": "f85552", "orange": "f57d26", "yellow": "dfa000", "green": "8da101",
              "aqua": "35a77c", "blue": "3a94c5", "purple": "df69ba", "grey0": "a6b0a0", "grey1": "939f91",
              "grey2": "829181"},
}
for (mode, contrast), (dim, bg0, bg1, bg2, bg3, bg4, bg5) in EVERFOREST_BG.items():
    f = EVERFOREST_FG[mode]
    if mode == "dark":
        ramp = {"crust": mix(dim, "000000", 0.2), "mantle": dim, "base": bg0, "surface0": bg1, "surface1": bg3,
                "subtext0": f["grey2"]}
    else:
        ramp = {"crust": bg2, "mantle": bg1, "base": bg0, "surface0": bg4, "surface1": bg5,
                "subtext0": mix(f["fg"], f["grey2"], 0.5)}
    SCHEMES.setdefault("everforest", {})[mode if contrast == "medium" else f"{mode}-{contrast}"] = {
        **ramp, "mode": mode, "overlay0": f["grey0"], "overlay1": f["grey1"], "text": f["fg"],
        "primary": f["green"], "secondary": f["aqua"], "tertiary": f["blue"], "red": f["red"], "green": f["green"],
        "term": ansi(bg3 if mode == "dark" else f["fg"], f["red"], f["green"], f["yellow"], f["blue"], f["purple"],
                     f["aqua"], f["grey2"] if mode == "dark" else bg5, f["grey0"] if mode == "dark" else f["grey2"],
                     f["fg"] if mode == "dark" else bg3),
    }

# --- Gruvbox: github.com/morhetz/gruvbox (colors/gruvbox.vim) -----------------------------------------------------
GB = {
    "dark0_hard": "1d2021", "dark0": "282828", "dark0_soft": "32302f", "dark1": "3c3836", "dark2": "504945",
    "dark3": "665c54", "dark4": "7c6f64", "gray": "928374", "light0_hard": "f9f5d7", "light0": "fbf1c7",
    "light0_soft": "f2e5bc", "light1": "ebdbb2", "light2": "d5c4a1", "light3": "bdae93", "light4": "a89984",
}
GB_BRIGHT = ["fb4934", "b8bb26", "fabd2f", "83a598", "d3869b", "8ec07c"]  # red green yellow blue purple aqua
GB_NEUTRAL = ["cc241d", "98971a", "d79921", "458588", "b16286", "689d6a"]
GB_FADED = ["9d0006", "79740e", "b57614", "076678", "8f3f71", "427b58"]
for mode in ("dark", "light"):
    for contrast in ("hard", "medium", "soft"):
        bg = GB[f"{mode}0" + ("" if contrast == "medium" else f"_{contrast}")]
        if mode == "dark":
            red, green, yellow, blue, purple, aqua = GB_BRIGHT
            ramp = {"crust": mix(bg, "000000", 0.3), "mantle": mix(bg, "000000", 0.15), "surface0": GB["dark1"],
                    "surface1": GB["dark2"], "overlay0": GB["dark4"], "overlay1": GB["gray"],
                    "subtext0": GB["light4"], "text": GB["light1"], "orange": "fe8019"}
            term = ansi(GB["dark0"], *GB_NEUTRAL, GB["light4"], GB["gray"], GB["light1"], GB_BRIGHT)
        else:
            red, green, yellow, blue, purple, aqua = GB_FADED
            ramp = {"crust": GB["light1"], "mantle": mix(bg, GB["light1"], 0.5), "surface0": GB["light2"],
                    "surface1": GB["light3"], "overlay0": GB["gray"], "overlay1": GB["dark4"],
                    "subtext0": GB["dark3"], "text": GB["dark1"], "orange": "af3a03"}
            term = ansi(GB["light0"], *GB_NEUTRAL, GB["dark4"], GB["gray"], GB["dark1"], GB_FADED)
        SCHEMES.setdefault("gruvbox", {})[mode if contrast == "medium" else f"{mode}-{contrast}"] = {
            **ramp, "mode": mode, "base": bg, "primary": yellow, "secondary": aqua, "tertiary": ramp.pop("orange"),
            "red": red, "green": green, "term": term,
        }

# --- Nord: https://www.nordtheme.com/docs/colors-and-palettes -----------------------------------------------------
SCHEMES["nord"] = {"default": {
    "mode": "dark", "crust": mix("2e3440", "000000", 0.3), "mantle": mix("2e3440", "000000", 0.15), "base": "2e3440",
    "surface0": "3b4252", "surface1": "434c5e", "overlay0": "616e88", "overlay1": mix("616e88", "d8dee9", 0.33),
    "subtext0": mix("d8dee9", "4c566a", 0.25), "text": "d8dee9",
    "primary": "88c0d0", "secondary": "81a1c1", "tertiary": "b48ead", "red": "bf616a", "green": "a3be8c",
    "term": ansi("3b4252", "bf616a", "a3be8c", "ebcb8b", "81a1c1", "b48ead", "88c0d0", "e5e9f0", "4c566a", "eceff4",
                 ["bf616a", "a3be8c", "ebcb8b", "81a1c1", "b48ead", "8fbcbb"]),
}}

# --- Old World: github.com/dgox16/oldworld.nvim (lua/oldworld/variants.lua) ---------------------------------------
OLDWORLD = {
    "default": {"bg": "161617", "bg_dark": "131314", "black": "27272a", "gray2": "2a2a2c", "gray4": "3b3b3e",
                "red": "ea83a5", "green": "90b99f", "yellow": "e6b99d", "purple": "aca1cf", "magenta": "e29eca",
                "blue": "92a2d5", "cyan": "85b5ba"},
    "cooler": {"bg": "161617", "bg_dark": "131314", "black": "27282a", "gray2": "2a2b2c", "gray4": "3b3c3e",
               "red": "ea83bf", "green": "90b995", "yellow": "e6a79d", "purple": "a1a1cf", "magenta": "e29edb",
               "blue": "92b3d5", "cyan": "85bab2"},
    "oled": {"bg": "000000", "bg_dark": "000000", "black": "161617", "gray2": "1b1b1c", "gray4": "313134",
             "red": "ea83a5", "green": "90b99f", "yellow": "e6b99d", "purple": "aca1cf", "magenta": "e29eca",
             "blue": "92a2d5", "cyan": "85b5ba"},
}
for flavour, o in OLDWORLD.items():
    fg, sub1, sub2, sub3, sub4 = ("c8c7cd", "b2b1ba", "9c9ca6", "888693", "696874") if flavour == "cooler" else \
        ("c9c7cd", "b4b1ba", "9f9ca6", "8b8693", "6c6874")
    SCHEMES.setdefault("oldworld", {})[flavour] = {
        "mode": "dark", "crust": mix(o["bg_dark"], "000000", 0.3), "mantle": o["bg_dark"], "base": o["bg"],
        "surface0": o["gray2"], "surface1": o["gray4"], "overlay0": sub4, "overlay1": sub3, "subtext0": sub2,
        "text": fg, "primary": o["purple"], "secondary": o["blue"], "tertiary": o["magenta"],
        "red": o["red"], "green": o["green"],
        "term": ansi(o["black"], o["red"], o["green"], o["yellow"], o["blue"], o["magenta"], o["cyan"], sub1, sub4, fg),
    }

# --- One Dark: github.com/atom/one-dark-syntax (styles/colors.less) -----------------------------------------------
SCHEMES["onedark"] = {"default": {
    "mode": "dark", "crust": mix("21252b", "000000", 0.2), "mantle": "21252b", "base": "282c34",
    "surface0": "2c313c", "surface1": "3e4451", "overlay0": "5c6370", "overlay1": mix("5c6370", "abb2bf", 0.3),
    "subtext0": mix("abb2bf", "5c6370", 0.25), "text": "abb2bf",
    "primary": "61afef", "secondary": "c678dd", "tertiary": "56b6c2", "red": "e06c75", "green": "98c379",
    "term": ansi("3e4451", "e06c75", "98c379", "e5c07b", "61afef", "c678dd", "56b6c2", "abb2bf", "5c6370", "ffffff"),
}}

# --- Rosé Pine: https://rosepinetheme.com/palette ----------------------------------------------------------------
ROSEPINE = {
    "main": {"nc": "16141f", "base": "191724", "surface": "1f1d2e", "overlay": "26233a", "muted": "6e6a86",
             "subtle": "908caa", "text": "e0def4", "love": "eb6f92", "gold": "f6c177", "rose": "ebbcba",
             "pine": "31748f", "foam": "9ccfd8", "iris": "c4a7e7", "leaf": "95b1ac", "hl_med": "403d52",
             "hl_high": "524f67"},
    "moon": {"nc": "1f1d30", "base": "232136", "surface": "2a273f", "overlay": "393552", "muted": "6e6a86",
             "subtle": "908caa", "text": "e0def4", "love": "eb6f92", "gold": "f6c177", "rose": "ea9a97",
             "pine": "3e8fb0", "foam": "9ccfd8", "iris": "c4a7e7", "leaf": "95b1ac", "hl_med": "44415a",
             "hl_high": "56526e"},
    "dawn": {"nc": "f8f0e7", "base": "faf4ed", "surface": "fffaf3", "overlay": "f2e9e1", "muted": "9893a5",
             "subtle": "797593", "text": "464261", "love": "b4637a", "gold": "ea9d34", "rose": "d7827e",
             "pine": "286983", "foam": "56949f", "iris": "907aa9", "leaf": "6d8f89", "hl_med": "dfdad9",
             "hl_high": "cecacd"},
}
for flavour, r in ROSEPINE.items():
    if flavour == "dawn":
        ramp = {"mode": "light", "crust": r["hl_med"], "mantle": r["overlay"], "surface0": r["hl_high"],
                "surface1": mix(r["hl_high"], r["muted"], 0.3), "subtext0": mix(r["text"], r["subtle"], 0.5)}
    else:
        ramp = {"mode": "dark", "crust": mix(r["nc"], "000000", 0.2), "mantle": r["nc"], "surface0": r["overlay"],
                "surface1": r["hl_med"], "subtext0": r["subtle"]}
    SCHEMES.setdefault("rosepine", {})[flavour] = {
        **ramp, "base": r["base"], "overlay0": r["muted"], "overlay1": mix(r["muted"], r["subtle"], 0.5),
        "text": r["text"], "primary": r["iris"], "secondary": r["foam"], "tertiary": r["rose"],
        "red": r["love"], "green": r["leaf"],
        # Rosé Pine's terminal ports: green is pine, blue is foam, cyan is rose
        "term": ansi(r["overlay"], r["love"], r["pine"], r["gold"], r["foam"], r["iris"], r["rose"], r["text"],
                     r["muted"], r["text"]),
    }

# --- Solarized: https://ethanschoonover.com/solarized -------------------------------------------------------------
SOL = {"base03": "002b36", "base02": "073642", "base01": "586e75", "base00": "657b83", "base0": "839496",
       "base1": "93a1a1", "base2": "eee8d5", "base3": "fdf6e3", "yellow": "b58900", "orange": "cb4b16",
       "red": "dc322f", "magenta": "d33682", "violet": "6c71c4", "blue": "268bd2", "cyan": "2aa198",
       "green": "859900"}
SOL_TERM = [SOL[k] for k in ("base02", "red", "green", "yellow", "blue", "magenta", "cyan", "base2", "base03",
                             "orange", "base01", "base00", "base0", "violet", "base1", "base3")]
SOL_ACCENTS = {"primary": SOL["blue"], "secondary": SOL["cyan"], "tertiary": SOL["violet"], "red": SOL["red"],
               "green": SOL["green"], "term": SOL_TERM}
SCHEMES["solarized"] = {
    "dark": {"mode": "dark", "crust": mix(SOL["base03"], "000000", 0.35), "mantle": mix(SOL["base03"], "000000", 0.2),
             "base": SOL["base03"], "surface0": SOL["base02"], "surface1": mix(SOL["base02"], SOL["base01"], 0.4),
             "overlay0": SOL["base01"], "overlay1": SOL["base00"], "subtext0": SOL["base0"], "text": SOL["base1"],
             **SOL_ACCENTS},
    "light": {"mode": "light", "crust": mix(SOL["base2"], SOL["base1"], 0.25), "mantle": SOL["base2"],
              "base": SOL["base3"], "surface0": mix(SOL["base2"], SOL["base1"], 0.45),
              "surface1": mix(SOL["base2"], SOL["base1"], 0.6), "overlay0": SOL["base1"], "overlay1": SOL["base0"],
              "subtext0": SOL["base00"], "text": SOL["base01"], **SOL_ACCENTS},
}

# --- Tokyo Night: github.com/folke/tokyonight.nvim (lua/tokyonight/colors) ----------------------------------------
TN = {"fg_gutter": "3b4261", "comment": "565f89", "dark5": "737aa2", "fg_dark": "a9b1d6", "fg": "c0caf5",
      "blue": "7aa2f7", "cyan": "7dcfff", "magenta": "bb9af7", "red": "f7768e", "green": "9ece6a",
      "yellow": "e0af68", "terminal_black": "414868", "bg_highlight": "292e42"}
TOKYONIGHT = {
    "night": {**TN, "bg": "1a1b26", "bg_dark": "16161e", "bg_dark1": "0c0e14"},
    "storm": {**TN, "bg": "24283b", "bg_dark": "1f2335", "bg_dark1": "1b1e2d"},
    "moon": {"fg_gutter": "3b4261", "comment": "636da6", "dark5": "737aa2", "fg_dark": "828bb8", "fg": "c8d3f5",
             "blue": "82aaff", "cyan": "86e1fc", "magenta": "c099ff", "red": "ff757f", "green": "c3e88d",
             "yellow": "ffc777", "terminal_black": "444a73", "bg_highlight": "2f334d", "bg": "222436",
             "bg_dark": "1e2030", "bg_dark1": "191b29"},
}
for flavour, t in TOKYONIGHT.items():
    SCHEMES.setdefault("tokyonight", {})[flavour] = {
        "mode": "dark", "crust": t["bg_dark1"], "mantle": t["bg_dark"], "base": t["bg"],
        "surface0": t["bg_highlight"], "surface1": t["fg_gutter"], "overlay0": t["comment"], "overlay1": t["dark5"],
        "subtext0": t["fg_dark"], "text": t["fg"], "primary": t["blue"], "secondary": t["magenta"],
        "tertiary": t["cyan"], "red": t["red"], "green": t["green"],
        "term": ansi(t["bg_dark"], t["red"], t["green"], t["yellow"], t["blue"], t["magenta"], t["cyan"], t["fg_dark"],
                     t["terminal_black"], t["fg"]),
    }


out_dir = Path(__file__).resolve().parent.parent / "assets" / "schemes"
written = set()
for name, flavours in SCHEMES.items():
    for flavour, slots in flavours.items():
        out = out_dir / name / f"{flavour}.json"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(scheme(name, flavour, slots), indent=4) + "\n")
        written.add(out)
# Remove schemes no longer generated, but keep the folder itself: a running shell watches it
for stale in set(out_dir.glob("*/*.json")) - written:
    stale.unlink()
for folder in out_dir.iterdir():
    if folder.is_dir() and not any(folder.iterdir()):
        folder.rmdir()
print(f"Wrote {sum(map(len, SCHEMES.values()))} schemes to {out_dir}")
