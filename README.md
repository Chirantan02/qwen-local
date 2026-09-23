# qwen-local — Uncensored Qwen-Image-2.1 on an 8GB laptop GPU

Local image generation + instruction-based image editing with **Qwen-Image-2.1** and the
abliterated ("Heretic") Qwen3-VL text encoder, running fully offline on an
**RTX 4060 Laptop (8GB VRAM) / 16GB RAM** via ComfyUI + GGUF quantization.

Uncensoring here is done by the **text encoder**, not a LoRA — the DiT is stock official
Qwen-Image-2.1 weights (Q4_K_M GGUF, only ~4.3GB because the 2.1 DiT is 7B, not 20B).

## What you get

| | |
|---|---|
| Text → image | ~97s warm @ 1024², 25 steps |
| Image edit (ref + prompt) | ~140–230s, up to 10 reference images |
| Quality | photoreal, readable text rendering, native 2K, native RGBA transparency |

## Components

| File | Repo | Size |
|---|---|---|
| `qwen_image_2.1-Q4_K_M.gguf` (DiT) | `pottokao/Qwen-Image-2.1-DiT-GGUF` | 4.34GB |
| `qwen3vl_8b_heretic-Q4_K_M.gguf` (uncensored TE) | `pottokao/Qwen-Image-2.1-Text-Encoder-Heretic-GGUF` | 5.03GB |
| `mmproj-qwen3vl_8b_heretic-f16.gguf` (vision tower — keep next to TE, don't rename) | same | 1.16GB |
| `qwen_image_2.1_vae_bf16.safetensors` | `Comfy-Org/Qwen-Image-2.1` → `vae/` path | 675MB |

Custom nodes: `city96/ComfyUI-GGUF` + `pottokao-dotcom/ComfyUI-GGUF-Qwen3VL-TE`.

## Setup (Windows)

```powershell
# 1. Download everything (~11GB, resumable; uses gh-proxy.com because GitHub
#    release assets are geo-throttled on this line)
powershell -File setup.ps1

# 2. Python venv + torch cu126 + deps
#    (system Python on this box has no venv module -> virtualenv)
powershell -File venv_setup.ps1

# 3. Launch ComfyUI
run_comfy_venv.bat        # -> http://127.0.0.1:8188
```

## Usage

**Edit an image with a prompt (CLI):**

```
C:\ComfyUI\venv\Scripts\python.exe edit.py ^
    --image path\to\photo.png ^
    --prompt "Change the fox's fur to bright blue, keep composition and text the same"
```

- `--image` accepts up to 10 reference files; the first sets output size
- flags: `--steps` (default 15, use 25 for finals), `--seed`, `--negative`,
  `--resolution` (1024; `0` = keep ref size), `--name`
- output → `ComfyUI\output\qwen21_edits\`

**Text→image:** load `workflow_api.json` in the browser UI, or POST it to `/prompt`.

## The recipe that actually works (hard-won)

- **Single KSamplerAdvanced, CFG 1.0, euler/simple.** CFG > 1 and the popular
  split-CFG (1.0→3.0) recipe produce pure noise garbage on this stack. Do not use CFG > 1.
- VAE **must** be the Comfy-Org bf16 repack (675MB) — the diffusers fp32 VAE throws a
  state_dict mismatch.
- Autogrow image inputs must be sent as dotted keys `"images.image_1": ["10",0]` —
  a plain `images: [[...]]` list is silently ignored (you get a hallucinated image
  that ignores your reference).
- 8GB VRAM can't hold DiT + TE at once; ComfyUI swaps ~7GB per run. Keep other apps
  closed (16GB RAM box) or run times double.
- Warmup after boot: any 4-step run at `--resolution 512` (~150s) loads everything.

## Samples

`output/qwen21_uncensored/` — text→image. `output/qwen21_edits/` — reference-guided edits.

## License note

DiT/VAE weights are `qwen-research` **non-commercial** license; the Heretic TE is
Apache-2.0. This repo contains **no weights** — `setup.ps1` downloads them from HuggingFace.
