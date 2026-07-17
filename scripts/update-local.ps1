#!/usr/bin/env pwsh
# Rebuild the personal fork and replace the locally installed Orca.
#
#   .\scripts\update-local.ps1            full rebuild + silent reinstall over existing install, then launch
#   .\scripts\update-local.ps1 -Fast      skip the installer, run dist\win-unpacked directly (fastest while iterating)
#   .\scripts\update-local.ps1 -Sync      rebase personal-fork onto origin/main first, then build
#   .\scripts\update-local.ps1 -NoLaunch  build/install but don't start Orca afterwards
#
# origin = stablyai/orca (upstream source), fork = saeedrahimi/orca (personal fork).
param([switch]$Sync, [switch]$Fast, [switch]$NoLaunch)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot\..

if ($Sync) {
  git fetch origin
  git rebase origin/main            # personal-fork onto upstream
}

pnpm install                         # rebuilds node-pty for Electron (postinstall)
pnpm run build:native                # compiles windows-cli-launcher orca.exe (fast, csc.exe)

if ($Fast) {
  pnpm run build:unpack              # dist\win-unpacked — run directly, no install
  $exe = Join-Path $PWD "dist\win-unpacked\Orca.exe"
} else {
  pnpm run build:win                 # dist\orca-windows-setup.exe
  # Free locked files before the silent upgrade (the NSIS daemon-stop hook only
  # runs on a real uninstall, not a silent /S upgrade).
  Get-Process Orca -ErrorAction SilentlyContinue | Stop-Process -Force
  Start-Process -Wait "dist\orca-windows-setup.exe" -ArgumentList "/S"  # silent in-place replace
  Write-Host "Installed."
  # perMachine:false → per-user NSIS install lands under LOCALAPPDATA\Programs.
  $exe = Join-Path $env:LOCALAPPDATA "Programs\orca\Orca.exe"
}

if ($NoLaunch) {
  Write-Host "Run: $exe"
} elseif (Test-Path $exe) {
  Start-Process $exe                 # detached — don't block the shell on the app
  Write-Host "Launched $exe"
} else {
  Write-Warning "Orca.exe not found at $exe — launch it from the Start Menu."
}
