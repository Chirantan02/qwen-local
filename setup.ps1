$ErrorActionPreference = 'Continue'
$root = 'C:\ComfyUI'
$dl   = "$root\downloads"
$log  = "$root\setup_log.txt"
New-Item -ItemType Directory -Force -Path $dl | Out-Null
function Log($m) { Add-Content -Path $log -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m" }

function Download($url, $out, $minBytes) {
    if ((Test-Path $out) -and ((Get-Item $out).Length -ge $minBytes)) { Log "SKIP (complete): $out"; return $true }
    for ($i = 1; $i -le 40; $i++) {
        Log "TRY $i : $url"
        curl.exe -sL --continue-at - --connect-timeout 20 --speed-time 60 --speed-limit 5120 --retry 3 -o $out $url
        if ((Test-Path $out) -and ((Get-Item $out).Length -ge $minBytes)) { Log "DONE: $out ($([math]::Round((Get-Item $out).Length/1GB,2)) GB)"; return $true }
        Start-Sleep -Seconds 5
    }
    Log "FAILED: $url"; return $false
}

Log "===== SETUP START ====="

$jobs = @(
  @{u='https://gh-proxy.com/https://github.com/comfyanonymous/ComfyUI/releases/download/latest/ComfyUI_windows_portable_nvidia.7z'; o="$dl\ComfyUI_windows_portable_nvidia.7z"; min=1500000000},
  @{u='https://huggingface.co/pottokao/Qwen-Image-2.1-DiT-GGUF/resolve/main/qwen_image_2.1-Q4_K_M.gguf'; o="$dl\qwen_image_2.1-Q4_K_M.gguf"; min=4335931552},
  @{u='https://huggingface.co/pottokao/Qwen-Image-2.1-Text-Encoder-Heretic-GGUF/resolve/main/qwen3vl_8b_heretic-Q4_K_M.gguf'; o="$dl\qwen3vl_8b_heretic-Q4_K_M.gguf"; min=5027785376},
  @{u='https://huggingface.co/pottokao/Qwen-Image-2.1-Text-Encoder-Heretic-GGUF/resolve/main/mmproj-qwen3vl_8b_heretic-f16.gguf'; o="$dl\mmproj-qwen3vl_8b_heretic-f16.gguf"; min=1159030464},
  @{u='https://huggingface.co/Qwen/Qwen-Image-2.1/resolve/main/vae/diffusion_pytorch_model.safetensors'; o="$dl\qwen_image_2.1_vae_bf16.safetensors"; min=1350989512},
  @{u='https://gh-proxy.com/https://github.com/city96/ComfyUI-GGUF/archive/refs/heads/main.zip'; o="$dl\gguf-node.zip"; min=30000},
  @{u='https://gh-proxy.com/https://github.com/pottokao-dotcom/ComfyUI-GGUF-Qwen3VL-TE/archive/refs/heads/main.zip'; o="$dl\qwen3vl-te-node.zip"; min=5000}
)

$ok = $true
foreach ($j in $jobs) { if (-not (Download $j.u $j.o $j.min)) { $ok = $false } }
if (-not $ok) { Log "===== SOME DOWNLOADS FAILED - rerun script to resume ====="; exit 1 }

Log "Installing py7zr..."
python -m pip install --quiet --disable-pip-version-check py7zr | Out-Null

Log "Extracting ComfyUI portable (this takes a while)..."
if (-not (Test-Path "$root\ComfyUI_windows_portable")) {
    python -c "import py7zr; py7zr.SevenZipFile(r'$dl\ComfyUI_windows_portable_nvidia.7z').extractall(r'$root')"
}
$pc  = "$root\ComfyUI_windows_portable"
$cui = "$pc\ComfyUI"
if (-not (Test-Path $cui)) { Log "FATAL: extraction failed, $cui missing"; exit 1 }
Log "Extracted OK"

Log "Placing model files..."
foreach ($d in @('diffusion_models','text_encoders','vae')) { New-Item -ItemType Directory -Force -Path "$cui\models\$d" | Out-Null }
Copy-Item "$dl\qwen_image_2.1-Q4_K_M.gguf"          "$cui\models\diffusion_models\" -Force
Copy-Item "$dl\qwen3vl_8b_heretic-Q4_K_M.gguf"      "$cui\models\text_encoders\" -Force
Copy-Item "$dl\mmproj-qwen3vl_8b_heretic-f16.gguf"  "$cui\models\text_encoders\" -Force
Copy-Item "$dl\qwen_image_2.1_vae_bf16.safetensors" "$cui\models\vae\" -Force

Log "Installing custom nodes..."
New-Item -ItemType Directory -Force -Path "$cui\custom_nodes" | Out-Null
$nodeMap = @{ "$dl\gguf-node.zip" = @('ComfyUI-GGUF-main','ComfyUI-GGUF'); "$dl\qwen3vl-te-node.zip" = @('ComfyUI-GGUF-Qwen3VL-TE-main','ComfyUI-GGUF-Qwen3VL-TE') }
foreach ($zip in $nodeMap.Keys) {
    $tmp = "$dl\ext_$([IO.Path]::GetFileNameWithoutExtension($zip))"
    Expand-Archive -Path $zip -DestinationPath $tmp -Force
    Copy-Item "$tmp\$($nodeMap[$zip][0])" "$cui\custom_nodes\$($nodeMap[$zip][1])" -Recurse -Force
    Remove-Item $tmp -Recurse -Force
}

Log "Installing node dependencies with embedded python..."
$pye = "$pc\python_embeded\python.exe"
foreach ($req in @("$cui\custom_nodes\ComfyUI-GGUF\requirements.txt", "$cui\custom_nodes\ComfyUI-GGUF-Qwen3VL-TE\requirements.txt")) {
    if (Test-Path $req) { & $pye -m pip install --quiet --disable-pip-version-check -r $req | Out-Null; Log "pip done: $req" }
}

Log "===== SETUP COMPLETE ====="
