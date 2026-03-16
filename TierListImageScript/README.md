# Tier List Image Script

Generates a tier list image from the app’s URL state or from random tiers (for layout tweaking).

## Build and run

From this directory:

```bash
swift build
swift run TierListImageScript --help
```

## Usage

### From a URL (e.g. iMessage game state)

```bash
swift run TierListImageScript "https://tierlist.game/g?state=..." [output.png]
```

If `output.png` is omitted, writes `tierlist.png` in the current directory.

### Random tiers (for layout tweaking)

Assigns each item in a template a random tier, then renders the image so you can adjust layout constants (row height, item size, spacing, etc.) in `Render.swift`:

```bash
swift run TierListImageScript --random <templateIndex> [output.png]
```

**Template indices:**  
0 = Ranked Anime, 1 = Movies, 2 = Video Games, 3 = Fast Food, 4 = Streaming Services, 5 = Cereals

Example:

```bash
swift run TierListImageScript --random 0 tierlist_random.png
```

If `output.png` is omitted, writes `tierlist_random_<index>.png`.

## Image layout

- **Width:** Largest tier row width (tier label + all items in that row).
- **Height:** Fixed — S, A, B, C, D rows stacked (5 × row height).
- **No title, no border.**
- **Tier letter:** S, A, B, C, D with the same background colors as the app (red, orange, yellow, green, blue).
- **Item area:** Black background; item images only, in the order given by the URL (item index order within each tier).

Layout constants (row height, tier label width, item size, spacing) are in `Sources/TierListImageScript/Render.swift`.
