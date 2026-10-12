$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    python tools/build.py
    if ($LASTEXITCODE -ne 0) { throw 'Build failed' }
} finally { Pop-Location }
