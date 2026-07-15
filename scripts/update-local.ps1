#!/usr/bin/env pwsh
# Rebuild the personal fork and replace the locally installed Orca.
#
#   .\scripts\update-local.ps1          full rebuild + silent reinstall over existing install
#   .\scripts\update-local.ps1 -Fast    skip the installer, run dist\win-unpacked directly (fastest while iterating)
#   .\scripts\update-local.ps1 -Sync    rebase personal-fork onto origin/main first, then build
#
# origin = stablyai/orca (upstream source), fork = saeedrahimi/orca (personal fork).
param([switch]$Sync, [switch]$Fast)

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
  Write-Host "Run: .\dist\win-unpacked\Orca.exe"
} else {
  pnpm run build:win                 # dist\orca-windows-setup.exe
  # Free locked files before the silent upgrade (the NSIS daemon-stop hook only
  # runs on a real uninstall, not a silent /S upgrade).
  Get-Process Orca -ErrorAction SilentlyContinue | Stop-Process -Force
  Start-Process -Wait "dist\orca-windows-setup.exe" -ArgumentList "/S"  # silent in-place replace
  Write-Host "Installed. Launch from Start Menu / desktop shortcut."
}
