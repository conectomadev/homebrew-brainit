#!/usr/bin/env pwsh
# brainit CLI installer for Windows (PowerShell).
#
#   irm https://raw.githubusercontent.com/conectomadev/homebrew-brainit/main/install.ps1 | iex
#
# Installs Bun if missing, downloads the brainit CLI package, fetches its
# runtime deps, and drops a `brainit` command on your PATH.
#
# Downloads come from the public GitHub release by default. Set $env:BRAINIT_BASE_URL
# to front them behind your own domain (expects <base>/releases/<ver>/brainit-cli.tar.gz).

$ErrorActionPreference = 'Stop'

$Repo    = 'conectomadev/homebrew-brainit'
$Version = if ($env:BRAINIT_VERSION) { $env:BRAINIT_VERSION } else { 'latest' }
$Prefix  = if ($env:BRAINIT_PREFIX)  { $env:BRAINIT_PREFIX }  else { "$env:LOCALAPPDATA\brainit" }
$BinDir  = if ($env:BRAINIT_BIN_DIR) { $env:BRAINIT_BIN_DIR } else { "$Prefix\bin" }

function Say($m) { Write-Host "> $m" -ForegroundColor Magenta }

if (-not (Get-Command tar -ErrorAction SilentlyContinue)) {
  throw "tar is required (ships with Windows 10 1803+)."
}

# 1. Ensure Bun.
$bun = (Get-Command bun -ErrorAction SilentlyContinue).Source
if (-not $bun) {
  $candidate = "$env:USERPROFILE\.bun\bin\bun.exe"
  if (Test-Path $candidate) { $bun = $candidate }
}
if (-not $bun) {
  Say "Installing Bun (JavaScript runtime)..."
  powershell -c "irm bun.sh/install.ps1 | iex"
  $bun = "$env:USERPROFILE\.bun\bin\bun.exe"
}
if (-not (Test-Path $bun)) { throw "Bun install failed; install it from https://bun.sh and re-run." }

# 2. Resolve the package tarball URL.
if ($env:BRAINIT_BASE_URL) {
  $Url = if ($Version -eq 'latest') { "$env:BRAINIT_BASE_URL/releases/latest/brainit-cli.tar.gz" }
         else                       { "$env:BRAINIT_BASE_URL/releases/$Version/brainit-cli.tar.gz" }
} elseif ($Version -eq 'latest') {
  $Url = "https://github.com/$Repo/releases/latest/download/brainit-cli.tar.gz"
} else {
  $Url = "https://github.com/$Repo/releases/download/$Version/brainit-cli.tar.gz"
}

# 3. Download + extract.
Say "Downloading brainit ($Version)..."
if (Test-Path $Prefix) { Remove-Item -Recurse -Force $Prefix }
New-Item -ItemType Directory -Force -Path $Prefix | Out-Null
$Tmp = Join-Path $env:TEMP 'brainit-cli.tar.gz'
Invoke-WebRequest -Uri $Url -OutFile $Tmp
tar -xzf $Tmp -C $Prefix
Remove-Item $Tmp

# 4. Fetch runtime deps.
Say "Installing runtime dependencies..."
Push-Location $Prefix
& $bun install --production
Pop-Location

# 5. Drop the launcher.
New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
$Cmd = "@echo off`r`n`"$bun`" `"$Prefix\cli\index.ts`" %*`r`n"
Set-Content -Path (Join-Path $BinDir 'brainit.cmd') -Value $Cmd -Encoding Ascii

# 6. Ensure BinDir is on the user PATH.
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike "*$BinDir*") {
  [Environment]::SetEnvironmentVariable('Path', "$userPath;$BinDir", 'User')
  Say "Added $BinDir to your PATH - restart your terminal to pick it up."
}

Say "Installed: $BinDir\brainit.cmd"
Say "Run it inside any repo:  brainit --yes"
