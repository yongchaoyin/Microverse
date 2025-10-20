# Images Output Point

This folder is the staging/output target for generated art assets before moving into `res://assets/...` paths used by Godot.

Suggested subfolders (optional):
- `ground/` — tilesets (grass, roads, water, cliffs, bridges)
- `buildings/` — residential/commercial/office/public
- `nature/` — trees, plants, decorations, water features
- `urban/` — street furniture, park equipment, vehicles
- `interior/` — office furniture and props

Naming conventions should match the prompt packs under `assets/prompts/` and the manifest `assets/manifest/asset_manifest.json` (e.g., `basic_grass.png`, `cafe.png`, `oak_tree.png`).

You can direct batch generation here first, review/retouch, then copy finalized assets into `res://assets/...` for the game.***
