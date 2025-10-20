# Generate Assets from YAML Prompts

This tool reads prompt packs in `assets/prompts/*.yaml`, expands macros from `_macros.yaml`, and (optionally) calls an Automatic1111 (Stable Diffusion) API to generate images into `images/`.

## Quick Start

1) Copy config and edit if needed  
`scripts/generate_assets/config.example.yaml` → `scripts/generate_assets/config.yaml`

2) (Optional) Create venv and install deps
```
python -m venv .venv
.venv\Scripts\activate
pip install -r scripts/generate_assets/requirements.txt
```

3) Run generator (dry-run by default)
```
python scripts/generate_assets/gen_from_yaml.py --config scripts/generate_assets/config.yaml
```
Dry-run writes a generation plan to `images/_planned.json` without rendering images.

4) Enable actual generation  
Set `dry_run: false` in the config and ensure A1111 API is reachable at `base_url`.

## Notes
- Output folders are pre-created at `images/ground`, `images/buildings`, `images/nature`, `images/urban`, `images/interior`.
- Autotile/animation hints are preserved to sidecar metadata for later Godot import.
- If you prefer ComfyUI/InvokeAI/OpenAI Images, tell us to add adapters.

