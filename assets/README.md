# Microverse Art Prompts & Manifest

This folder contains AI prompt packs and a lightweight manifest to generate Stardew-like town map assets consistent with:

- docs/design/小镇地图资源生成提示词.md
- docs/design/17_地图系统与场景设计规范.md
- docs/design/18_美术资源与视觉规范.md
- docs/requirements_summary.md

## How To Use

- Prompt packs live in `assets/prompts/*.yaml`.
- Each pack references shared macros in `assets/prompts/_macros.yaml` (style, palette, negative prompts, animation timing).
- The manifest `assets/manifest/asset_manifest.json` lists the packs and target Godot paths (`res://assets/...`).

Recommended SD settings (guide, adjust per model):
- sampler: `Euler a`, steps: 30, cfg: 7.5
- Size: per item `size_px`. For 16x16 tiles, generate at 1x or 2x and downscale with nearest.
- For tileable ground, enable tiling or use seamless generation; verify edge wrap.
- Avoid anti-aliasing and gradients; stick to the provided palette hues.

## Packs

- `ground.yaml` — grass, roads (autotiles), sand, water (4f anim), cliff-edge, bridge.
- `buildings.yaml` — residential (8), commercial (7), office (4), public (6).
- `nature.yaml` — trees with seasonal variants, small plants, park decor, water features.
- `urban.yaml` — street furniture, park equipment, vehicles (static).
- `interior_office.yaml` — desks, chairs, meeting furniture, props.

## Notes

- Tile size is 16×16 px. Buildings snap to a 16 px grid.
- Water and foliage include simple loop animations per design spec.
- Seasonal variants (spring/summer/autumn/winter) enable TimeSystem-driven swaps.

