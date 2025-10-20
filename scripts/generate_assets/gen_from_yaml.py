#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Batch generator for Microverse art assets from YAML prompt packs.
Default engine: Automatic1111 (txt2img).
"""
from __future__ import annotations
import argparse
import json
import os
import sys
import glob
import re
import time
from typing import Any, Dict, List, Optional, Tuple

try:
    import yaml  # PyYAML
except Exception as e:
    print("Missing dependency: PyYAML. Install via:\n  pip install -r scripts/generate_assets/requirements.txt", file=sys.stderr)
    sys.exit(2)

try:
    import requests
except Exception as e:
    print("Missing dependency: requests. Install via:\n  pip install -r scripts/generate_assets/requirements.txt", file=sys.stderr)
    sys.exit(2)

from tenacity import retry, wait_fixed, stop_after_attempt

# ----------------------------
# Utils
# ----------------------------
def load_yaml(path: str) -> Dict[str, Any]:
    with open(path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f) or {}

def ensure_dir(path: str) -> None:
    os.makedirs(path, exist_ok=True)

def slugify(name: str) -> str:
    return re.sub(r"[^a-zA-Z0-9_\\-\\.]+", "_", name.strip())

def read_config(path: str) -> Dict[str, Any]:
    cfg = load_yaml(path)
    if not cfg:
        raise RuntimeError(f"Empty config: {path}")
    # defaults
    cfg.setdefault("engine", "a1111")
    cfg.setdefault("base_url", "http://127.0.0.1:7860")
    cfg.setdefault("output_root", "images")
    cfg.setdefault("render", {})
    cfg["render"].setdefault("steps", 30)
    cfg["render"].setdefault("cfg_scale", 7.5)
    cfg["render"].setdefault("sampler_name", "Euler a")
    cfg["render"].setdefault("seed", -1)
    cfg.setdefault("dry_run", True)
    cfg.setdefault("timeout_s", 60)
    return cfg

# ----------------------------
# Prompt pack parsing
# ----------------------------
def load_macros(path: str) -> Dict[str, Any]:
    return load_yaml(path)

def resolve_prompt(text: str, macros: Dict[str, Any]) -> str:
    if not isinstance(text, str):
        return ""
    base = macros.get("prompts", {}).get("base", "")
    neg = macros.get("prompts", {}).get("negative", "")
    out = text.replace("@base", base).replace("@negative", neg)
    return re.sub(r"\s+", " ", out).strip()

def pack_output_base(meta_pack: str, output_root: str) -> str:
    mp = (meta_pack or "").lower()
    if "ground" in mp or "terrain" in mp:
        return os.path.join(output_root, "ground")
    if "building" in mp:
        return os.path.join(output_root, "buildings")
    if "nature" in mp or "water" in mp:
        return os.path.join(output_root, "nature")
    if "urban" in mp or "vehicle" in mp:
        return os.path.join(output_root, "urban")
    if "interior" in mp:
        return os.path.join(output_root, "interior")
    # fallback
    return os.path.join(output_root, slugify(meta_pack or "pack"))

def collect_items_from_pack(pack: Dict[str, Any]) -> List[Dict[str, Any]]:
    items: List[Dict[str, Any]] = []
    # common sections
    if "assets" in pack:
        for it in pack["assets"] or []:
            it2 = dict(it)
            it2["_section"] = "assets"
            items.append(it2)
    # groups
    if "groups" in pack:
        for grp in pack["groups"] or []:
            for it in grp.get("items", []) or []:
                it2 = dict(it)
                it2["_section"] = grp.get("name", "group")
                it2["_save_dir"] = grp.get("save_dir")
                items.append(it2)
    # other top-level collections with 'items'
    for k, v in pack.items():
        if k in ("meta", "defaults", "assets", "groups"):
            continue
        if isinstance(v, dict) and "items" in v:
            for it in v["items"] or []:
                it2 = dict(it)
                it2["_section"] = k
                it2["_save_dir"] = v.get("save_dir")
                items.append(it2)
    return items

# ----------------------------
# A1111 client
# ----------------------------
class A1111Client:
    def __init__(self, base_url: str, timeout: int = 60):
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout

    @retry(wait=wait_fixed(1), stop=stop_after_attempt(2))
    def txt2img(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        url = f"{self.base_url}/sdapi/v1/txt2img"
        r = requests.post(url, json=payload, timeout=self.timeout)
        r.raise_for_status()
        return r.json()

# ----------------------------
# Generation plan + run
# ----------------------------
def make_generation_tasks(pack_path: str, cfg: Dict[str, Any]) -> Dict[str, Any]:
    pack = load_yaml(pack_path)
    if not pack:
        return {"pack_path": pack_path, "items": []}
    macros_path = pack.get("meta", {}).get("macros") or "assets/prompts/_macros.yaml"
    macros = load_macros(macros_path) if os.path.exists(macros_path) else {}
    defaults = pack.get("defaults", {}).get("apply", {})
    base_out = pack_output_base(pack.get("meta", {}).get("pack", ""), cfg["output_root"])
    ensure_dir(base_out)

    render_defaults = macros.get("render_defaults", {})
    anim_defaults = macros.get("animation_defaults", {})

    items = collect_items_from_pack(pack)
    tasks: List[Dict[str, Any]] = []
    for it in items:
        file_name = it.get("file") or f"{it.get('id','item')}.png"
        base_name, ext = os.path.splitext(file_name)

        # Dimensions
        size = it.get("size_px") or defaults.get("tile_size") or [16, 16]
        width, height = int(size[0]), int(size[1])

        # Prompts
        prompt = resolve_prompt(it.get("prompt") or defaults.get("base_prompt", ""), macros)
        negative = resolve_prompt(it.get("negative") or defaults.get("negative_prompt", ""), macros)

        # Output dir considering save_dir if present
        subdir = it.get("_save_dir") or ""
        out_dir = os.path.join(base_out, subdir) if subdir else base_out
        ensure_dir(out_dir)

        # Variants expansions
        variants = it.get("variants") or []
        seasonal = it.get("seasonal_variants") or []
        animation = it.get("animation") or {}
        frames = int(animation.get("frames") or 1)
        frame_duration = float(animation.get("frame_duration_s") or anim_defaults.get("water_frame_duration_s", 0.3))

        # Tileable hint
        tileable = bool(it.get("tileable") or (it.get("kind") in ("tile", "autotile", "animated_tile")))

        # Build task variations
        base_task = dict(
            out_dir=out_dir,
            base_name=base_name,
            ext=ext or ".png",
            width=width,
            height=height,
            prompt=prompt,
            negative=negative,
            steps=cfg["render"]["steps"],
            cfg_scale=cfg["render"]["cfg_scale"],
            sampler_name=cfg["render"]["sampler_name"],
            seed=cfg["render"]["seed"],
            tiling=tileable,
            meta={
                "pack": pack.get("meta", {}).get("pack", ""),
                "section": it.get("_section"),
                "anim_frames": frames,
                "anim_frame_duration_s": frame_duration,
                "autotile_mask": it.get("autotile_mask"),
                "kind": it.get("kind"),
            }
        )

        def enqueue(sfx: str, extra_prompt: Optional[str] = None, frame_idx: Optional[int] = None):
            t = dict(base_task)
            t["file_name"] = f"{base_name}{sfx}{ext}"
            if extra_prompt:
                t["prompt"] = f"{t['prompt']}, {extra_prompt}".strip().strip(",")
            if frame_idx is not None:
                t["meta"]["frame_index"] = frame_idx
            tasks.append(t)

        if variants:
            for v in variants:
                sfx = f"__{slugify(str(v))}"
                if frames > 1:
                    for fidx in range(frames):
                        enqueue(f"{sfx}__f{fidx}", extra_prompt=f"frame {fidx+1} of {frames}", frame_idx=fidx)
                else:
                    enqueue(sfx)
        elif seasonal:
            for s in seasonal:
                sfx = f"__season_{slugify(str(s))}"
                if frames > 1:
                    for fidx in range(frames):
                        enqueue(f"{sfx}__f{fidx}", extra_prompt=f"{s} season, frame {fidx+1} of {frames}", frame_idx=fidx)
                else:
                    enqueue(sfx, extra_prompt=f"{s} season")
        elif frames > 1:
            for fidx in range(frames):
                enqueue(f"__f{fidx}", extra_prompt=f"frame {fidx+1} of {frames}", frame_idx=fidx)
        else:
            enqueue("")

    return {
        "pack_path": pack_path,
        "macros": macros_path,
        "tasks": tasks,
    }

def save_plan(plan: Dict[str, Any], out_path: str) -> None:
    ensure_dir(os.path.dirname(out_path))
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(plan, f, ensure_ascii=False, indent=2)

def run_task_a1111(client: A1111Client, t: Dict[str, Any]) -> bytes:
    payload = {
        "prompt": t["prompt"],
        "negative_prompt": t["negative"],
        "width": t["width"],
        "height": t["height"],
        "steps": t["steps"],
        "cfg_scale": t["cfg_scale"],
        "sampler_name": t["sampler_name"],
        "seed": t["seed"],
        "tiling": bool(t["tiling"]),
    }
    data = client.txt2img(payload)
    if not data or "images" not in data or not data["images"]:
        raise RuntimeError("A1111 returned no images")
    # images are base64-encoded PNGs
    import base64
    img_b64 = data["images"][0]
    return base64.b64decode(img_b64)

def write_bytes(path: str, content: bytes) -> None:
    ensure_dir(os.path.dirname(path))
    with open(path, "wb") as f:
        f.write(content)

def main():
    ap = argparse.ArgumentParser(description="Generate assets from YAML prompt packs.")
    ap.add_argument("--config", default="scripts/generate_assets/config.yaml", help="Path to config YAML.")
    args = ap.parse_args()

    cfg = read_config(args.config)
    packs = []
    for pattern in cfg.get("pack_globs", ["assets/prompts/*.yaml"]):
        packs.extend(glob.glob(pattern))
    exclude = set(cfg.get("exclude", []))
    packs = [p for p in packs if os.path.basename(p) not in {os.path.basename(e) for e in exclude}]
    packs.sort()

    all_tasks: List[Dict[str, Any]] = []
    per_pack_plans: List[Dict[str, Any]] = []
    for p in packs:
        plan = make_generation_tasks(p, cfg)
        per_pack_plans.append(plan)
        all_tasks.extend(plan["tasks"])

    # Save global plan
    plan_out = os.path.join(cfg["output_root"], "_planned.json")
    save_plan({"packs": per_pack_plans, "total_tasks": len(all_tasks)}, plan_out)
    print(f"[plan] Wrote generation plan with {len(all_tasks)} tasks -> {plan_out}")

    if cfg.get("dry_run", True):
        print("[dry-run] Skipping image generation.")
        return 0

    if cfg["engine"] != "a1111":
        print(f"Unsupported engine: {cfg['engine']}. Only 'a1111' is implemented.", file=sys.stderr)
        return 3

    client = A1111Client(cfg["base_url"], timeout=int(cfg.get("timeout_s", 60)))
    ok, fail = 0, 0
    for t in all_tasks:
        out_path = os.path.join(t["out_dir"], t["file_name"])
        try:
            png_bytes = run_task_a1111(client, t)
            write_bytes(out_path, png_bytes)
            # write sidecar meta
            meta_path = out_path + ".meta.json"
            with open(meta_path, "w", encoding="utf-8") as f:
                json.dump(t["meta"], f, ensure_ascii=False, indent=2)
            ok += 1
            print(f"[ok] {out_path}")
        except Exception as e:
            fail += 1
            print(f"[fail] {out_path} :: {e}", file=sys.stderr)
            continue
        time.sleep(0.05)  # tiny pacing

    print(f"Done. success={ok}, failed={fail}")
    return 0 if fail == 0 else 1

if __name__ == "__main__":
    sys.exit(main())

