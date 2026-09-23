# Uncensored Qwen-Image-2.1 — Local Setup (RTX 4060 Laptop)

**Path:** `C:\ComfyUI\PROJECT.md` · **Updated:** 2026-09-23 17:10 IST · **Status: install DONE, venv building, workflow pending**

---

## 1. What we're doing

Running **uncensored Qwen-Image-2.1 image generation fully locally** — no cloud, no API costs, private — targeting **~1 image/min at 1024²**. End goal: package the setup as a **GitHub repo** (code + scripts + workflow JSON; weights are downloaded by the user, never committed).

The "uncensored" part is **not a LoRA or fine-tune**. It's an **abliterated ("Heretic") text encoder**: refusals live in the language model that reads your prompt, so replacing only that component removes the refusal gate (100/100 → ~5/100 refusals) while the image weights stay 100% official — zero quality loss.

Source: @Israililv2 X post → HF repos by `pottokao`.

## 2. Target hardware (verified 2026-09-23)

| Part | Spec | Notes |
|---|---|---|
| GPU | RTX 4060 Laptop, **8 GB VRAM** | check with `nvidia-smi`, not WMI |
| CPU | i7-14700HX, 20C/28T | |
| RAM | 16 GB | tight but sufficient (~11 GB models, streamed) |
| Disk | C: only, ~92 GB freed for this | no D: drive |
| Line | ~3–5 MB/s real ceiling | GitHub release assets geo-throttled to 0.17 MB/s → **always use `https://gh-proxy.com/<github-url>` for GitHub binaries**; HF CDN is fine direct |

## 3. Why this model runs here (key fact)

**Qwen-Image-2.1's DiT is only 7B params** (the original Qwen-Image was 20B). At Q4_K_M the whole pipeline is ~10.8 GB total and the DiT is 4.04 GB — fits 8 GB VRAM comfortably. Expected: **60–100 s/image** at 1024²/25 steps, **40–70 s** at 15 steps; first image +20–30 s cold load, repeats stay cached.

## 4. Components installed

| Component | File | Size | Location |
|---|---|---|---|
| ComfyUI (portable, 0.36+) | `ComfyUI_windows_portable\` | ~5 GB unpacked | `C:\ComfyUI\ComfyUI_windows_portable\` |
| DiT (official, Q4_K_M) | `qwen_image_2.1-Q4_K_M.gguf` | 4.34 GB | `...\ComfyUI\models\diffusion_models\` |
| Heretic text encoder (Q4_K_M) | `qwen3vl_8b_heretic-Q4_K_M.gguf` | 5.03 GB | `...\ComfyUI\models\text_encoders\` |
| Vision tower (**must sit beside TE, never rename**) | `mmproj-qwen3vl_8b_heretic-f16.gguf` | 1.16 GB | `...\ComfyUI\models\text_encoders\` |
| VAE (official bf16) | `qwen_image_2.1_vae_bf16.safetensors` | 1.35 GB | `...\ComfyUI\models\vae\` |
| GGUF loader node | `ComfyUI-GGUF` (city96) | 37 KB | `...\ComfyUI\custom_nodes\` |
| Qwen3-VL TE patch node | `ComfyUI-GGUF-Qwen3VL-TE` (pottokao-dotcom) | small, zero deps | `...\ComfyUI\custom_nodes\` |

Sources (all verified live):
- `huggingface.co/pottokao/Qwen-Image-2.1-DiT-GGUF`
- `huggingface.co/pottokao/Qwen-Image-2.1-Text-Encoder-Heretic-GGUF`
- `huggingface.co/Qwen/Qwen-Image-2.1` (VAE: `vae/diffusion_pytorch_model.safetensors`)
- `github.com/city96/ComfyUI-GGUF` · `github.com/pottokao-dotcom/ComfyUI-GGUF-Qwen3VL-TE`

## 5. Setup scripts (detached, resumable)

| Script | Role | Log |
|---|---|---|
| `C:\ComfyUI_setup\setup.ps1` | downloads all files (curl resume + retry), extracts .7z via py7zr, places models, installs nodes. **Re-run to resume; completed files are skipped.** | `C:\ComfyUI\setup_log.txt` → `SETUP COMPLETE` ✅ |
| `C:\ComfyUI_setup\venv_setup.ps1` | builds **separate venv** `C:\ComfyUI\venv` (virtualenv — system Python lacks stdlib `venv`), installs CUDA torch cu126 + ComfyUI + node reqs, verifies GPU | `C:\ComfyUI\venv_log.txt` → `VENV SETUP COMPLETE` 🔄 in progress |

## 6. How to run

**Right now (embedded python, works today):**
```
C:\ComfyUI\ComfyUI_windows_portable\run_nvidia_gpu.bat
```
→ browser at `http://127.0.0.1:8188`

**Repo-style (current, working):**
```
C:\ComfyUI\run_comfy_venv.bat        # detached boot, logs to C:\ComfyUI\comfyui_log.txt
```

**Health check in the console:** `[GGUF-Qwen3VL-TE] added 351 Qwen3-VL vision tensors from mmproj.` — if you see this, the uncensored encoder loaded correctly.

## 7. Workflow — PROVEN WORKING (2026-09-23 18:30)

**Recipe (matches official Comfy-Org template):** `UnetLoaderGGUF` + `CLIPLoaderGGUF` (type `qwen_image`, Heretic file) + `VAELoader` (**Comfy-Org bf16 VAE, 675 MB** — NOT the diffusers fp32 1.35 GB file, it breaks with a state_dict size mismatch) + `TextEncodeQwenImage21` (prompt + negative built in) + `EmptyLatentImage` + **single `KSamplerAdvanced`, cfg 1.0, 25 steps, euler/simple** → VAEDecode → SaveImage.
- ⚠️ pottokao README's split-CFG (1.0→3.0) produced heavy noise + alpha speckle garbage — do NOT use CFG > 1 on this stack.
- Measured: **97 s/image warm @ 1024²/25 steps**, 257 s cold. Native 2K (2048²) supported.
- API workflow: `C:\ComfyUI\workflow_api.json` · outputs: `C:\ComfyUI\ComfyUI\output\qwen21_uncensored\`
- Extras: native transparency (RGBA VAE), edits with up to 10 reference images.
- Run via venv: `C:\ComfyUI\run_comfy_venv.bat` → `C:\ComfyUI\venv\Scripts\python.exe C:\ComfyUI\ComfyUI\main.py` (source install at `C:\ComfyUI\ComfyUI`; the broken py7zr portable tree is unused legacy).

## 7b. Image-edit CLI — `C:\ComfyUI\edit.py` (PROVEN 2026-09-23 18:50)

Transform an image with a text prompt, no browser needed. Requires the server running (§6).

```
C:\ComfyUI\venv\Scripts\python.exe C:\ComfyUI\edit.py ^
    --image path\to\photo.png ^
    --prompt "Transform this into a watercolor painting, same composition"
```

- `--image` takes **up to 10** reference files (space-separated); the first one sets the output size. Files are auto-copied into `ComfyUI\input\`.
- Other flags: `--negative`, `--steps` (default 25), `--seed` (default random), `--resolution` (default 1024; `0` keeps each reference's own size), `--name` (output prefix).
- Uses the same single-sampler CFG 1.0 recipe; wires `LoadImage → TextEncodeQwenImage21` via **dotted autogrow keys** `"images.image_1": ["10",0]`, `"images.image_2": ...` (a plain `images: [[link]]` or bare `image_1` key is silently ignored / errors — only the dotted form groups correctly), plus `vae` linked into the TE node (required for reference latents), then latent output `["4",2]` → `KSamplerAdvanced`.
- Outputs: `C:\ComfyUI\ComfyUI\output\qwen21_edits\`.
- Measured: **111 s** per 15-step edit on an idle machine (warm). 25-step ≈ 225s. Up to 449s when other apps eat RAM — close everything while generating. Re-identical prompt+seed = ~3s (node cache).

## 8. GitHub repo plan

Commit: `setup.ps1` (download script), `requirements.txt`, workflow JSON, README, this doc.
Never commit: model weights (11 GB), `venv/`, `downloads/`.
**License:** DiT/VAE are `qwen-research` **non-commercial**; TE is Apache-2.0. Fine to share setup + workflow; do not sell access to the weights or rehost them.

## 9. Known gotchas (all hit & fixed once)

1. WMI reports 4 GB VRAM for this GPU — trust `nvidia-smi` (8188 MiB).
2. GitHub direct release downloads crawl → gh-proxy.com mirror.
3. No 7-Zip on the machine → extract via `pip install py7zr`.
4. System Python has no `venv` module → use `python -m virtualenv`.
5. Node repo zips are ~37 KB — don't set min-size sanity checks above 100 KB or you get infinite retry loops.
6. Never rename the TE + mmproj files — the patch matches tensors by filename.
7. 16 GB RAM: close browsers/Electron apps before generating.

## 10. Next actions

- [ ] venv log shows `CUDA_OK: True`
- [ ] Boot ComfyUI on venv python, confirm 351-tensor patch line
- [ ] Author + test `qwen_image_2.1_uncensored.json` workflow, time first image
- [ ] Optional speed test: 15-step variant, then Qwen-Image-Lightning LoRA if still >60 s
- [ ] Scaffold repo folder + README + .gitignore, push
