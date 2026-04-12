$ErrorActionPreference = "Stop"

Set-Location $PSScriptRoot

try {
    python .\build.py

    $archivePath = Join-Path $PSScriptRoot "codexproxyd.tar.gz"
    Write-Host ""
    Write-Host "Build completed:" -ForegroundColor Green
    Write-Host $archivePath -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Upload this file to the router Software Center for offline install." -ForegroundColor Yellow
}
catch {
    Write-Host ""
    Write-Host "Build failed:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

Write-Host ""
Read-Host "Press Enter to close"
