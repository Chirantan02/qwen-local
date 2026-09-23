#!/usr/bin/env python
"""Qwen-Image-2.1 (uncensored Heretic TE) image-edit CLI.

Usage:
  python edit.py --image path/to/pic.png --prompt "transform it into ..."
  python edit.py --image a.png b.png --prompt "put b on top of a" --steps 25 --seed 7
"""
import argparse, json, os, shutil, sys, time, urllib.request, uuid

SERVER = "http://127.0.0.1:8188"
COMFY = r"C:\ComfyUI\ComfyUI"
INPUT_DIR = os.path.join(COMFY, "input")
OUT_DIR = os.path.join(COMFY, "output", "qwen21_edits")

DIT = "qwen_image_2.1-Q4_K_M.gguf"
TE = "qwen3vl_8b_heretic-Q4_K_M.gguf"
VAE = "qwen_image_2.1_vae_bf16.safetensors"

def api(path, payload=None):
    data = json.dumps(payload).encode() if payload else None
    req = urllib.request.Request(SERVER + path, data=data,
                                 headers={"Content-Type": "application/json"})
    return json.load(urllib.request.urlopen(req))

def main():
    p = argparse.ArgumentParser(description="Edit/transform images with Qwen-Image-2.1")
    p.add_argument("--image", nargs="+", required=True,
                   help="reference image path(s), up to 10; the first one sets output size")
    p.add_argument("--prompt", required=True, help="edit instruction in plain English")
    p.add_argument("--negative", default="", help="negative prompt (optional)")
    p.add_argument("--steps", type=int, default=15)
    p.add_argument("--seed", type=int, default=None, help="fixed seed (default: random)")
    p.add_argument("--resolution", type=int, default=1024,
                   help="references resized to ~N x N px (default 1024; 0 = keep original size)")
    p.add_argument("--name", default="edit", help="output filename prefix")
    a = p.parse_args()

    # stage reference images into ComfyUI input dir
    staged = []
    for src in a.image[:10]:
        if not os.path.isfile(src):
            sys.exit(f"file not found: {src}")
        dst = os.path.join(INPUT_DIR, os.path.basename(src))
        if os.path.abspath(src) != os.path.abspath(dst):
            shutil.copy2(src, dst)
        staged.append(os.path.basename(src))

    seed = a.seed if a.seed is not None else uuid.uuid4().int % 2**32
    graph = {
        "1": {"class_type": "UnetLoaderGGUF", "inputs": {"unet_name": DIT}},
        "2": {"class_type": "CLIPLoaderGGUF", "inputs": {"clip_name": TE, "type": "qwen_image", "device": "default"}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": VAE}},
        "4": {"class_type": "TextEncodeQwenImage21", "inputs": {
            "clip": ["2", 0], "prompt": a.prompt, "negative_prompt": a.negative,
            "resolution": a.resolution, "vae": ["3", 0],
            **{f"images.image_{i+1}": [str(10 + i), 0] for i in range(len(staged))}}},
    }
    for i, name in enumerate(staged):
        graph[str(10 + i)] = {"class_type": "LoadImage", "inputs": {"image": name}}
    graph["6"] = {"class_type": "KSamplerAdvanced", "inputs": {
        "model": ["1", 0], "add_noise": "enable", "noise_seed": seed,
        "steps": a.steps, "cfg": 1.0, "sampler_name": "euler", "scheduler": "simple",
        "positive": ["4", 0], "negative": ["4", 1], "latent_image": ["4", 2],
        "start_at_step": 0, "end_at_step": a.steps, "return_with_leftover_noise": "disable"}}
    graph["8"] = {"class_type": "VAEDecode", "inputs": {"samples": ["6", 0], "vae": ["3", 0]}}
    graph["9"] = {"class_type": "SaveImage", "inputs": {"images": ["8", 0],
                "filename_prefix": "qwen21_edits/" + a.name}}

    try:
        r = api("/prompt", {"prompt": graph, "client_id": "edit-cli"})
    except urllib.error.HTTPError as e:
        sys.exit("ComfyUI rejected the prompt:\n" + e.read().decode()[:800])
    pid = r["prompt_id"]
    print(f"queued {pid}  seed={seed}  refs={staged}")
    t0 = time.time()
    while True:
        time.sleep(3)
        try:
            h = api("/history/" + pid)
        except Exception:
            continue
        if pid in h:
            items = h[pid].get("outputs", {})
            for nid, out in items.items():
                for img in out.get("images", []):
                    path = os.path.join(OUT_DIR if img["subfolder"] == "qwen21_edits"
                                        else os.path.join(COMFY, "output", img["subfolder"]),
                                        img["filename"])
                    print(f"done in {time.time()-t0:.0f}s -> {path}")
            if not items:
                err = h[pid].get("status", {})
                print("finished with no output:", json.dumps(err)[:500])
            return

if __name__ == "__main__":
    main()
