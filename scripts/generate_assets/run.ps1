Param(
  [string]$ConfigPath = "scripts/generate_assets/config.yaml"
)

Write-Host "== Microverse Asset Generator ==" -ForegroundColor Cyan

if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
  Write-Error "Python is not available in PATH. Please install Python 3.9+."
  exit 1
}

$venv = ".venv"
if (-not (Test-Path $venv)) {
  python -m venv $venv
}

. "$venv/Scripts/Activate.ps1"

pip install -r scripts/generate_assets/requirements.txt

python scripts/generate_assets/gen_from_yaml.py --config $ConfigPath

