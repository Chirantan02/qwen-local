$ErrorActionPreference = 'Continue'
$root = 'C:\ComfyUI'
$log  = "$root\venv_log.txt"
function Log($m) { Add-Content -Path $log -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m" }

Log "===== VENV SETUP START ====="
Log "Creating venv..."
python -m pip install --quiet --disable-pip-version-check virtualenv
python -m virtualenv "$root\venv"
$py = "$root\venv\Scripts\python.exe"

Log "Upgrading pip..."
& $py -m pip install --quiet --upgrade pip | Out-Null

Log "Installing CUDA PyTorch (big download, ~3GB)..."
& $py -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu126
Log "torch exit code: $LASTEXITCODE"

Log "Installing ComfyUI requirements..."
& $py -m pip install --disable-pip-version-check -r "$root\ComfyUI_windows_portable\ComfyUI\requirements.txt"
Log "comfy reqs exit code: $LASTEXITCODE"

Log "Installing ComfyUI-GGUF node requirements..."
& $py -m pip install --disable-pip-version-check -r "$root\ComfyUI_windows_portable\ComfyUI\custom_nodes\ComfyUI-GGUF\requirements.txt"
Log "gguf reqs exit code: $LASTEXITCODE"

Log "Verifying GPU access..."
& $py -c "import torch; print('CUDA_OK:', torch.cuda.is_available(), torch.cuda.get_device_name(0) if torch.cuda.is_available() else '')"
Log "verify exit code: $LASTEXITCODE"
Log "===== VENV SETUP COMPLETE ====="
