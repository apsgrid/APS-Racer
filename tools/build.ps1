param(
    [switch]$SkipTests,
    [switch]$WebOnly,
    [switch]$WindowsOnly,
    [switch]$AndroidOnly
)

$ErrorActionPreference = 'Stop'
$Project = Split-Path -Parent $PSScriptRoot
$Godot = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe" -Filter "Godot_v4.7.2-stable_win64_console.exe" -Recurse -ErrorAction Stop | Select-Object -First 1 -ExpandProperty FullName

$OnlyMode = $WebOnly -or $WindowsOnly -or $AndroidOnly
$BuildWeb = (-not $OnlyMode) -or $WebOnly
$BuildWindows = (-not $OnlyMode) -or $WindowsOnly
$BuildAndroid = (-not $OnlyMode) -or $AndroidOnly

if (-not $SkipTests) {
    & py (Join-Path $Project "tools\validate_art_assets.py")
    if ($LASTEXITCODE -ne 0) { throw "Art asset validation failed." }

    & $Godot --headless --path $Project --script res://handling_tests.gd
    if ($LASTEXITCODE -ne 0) { throw "Handling tests failed." }

    & $Godot --headless --path $Project --script res://race_tests.gd
    if ($LASTEXITCODE -ne 0) { throw "Race tests failed." }
}

if ($BuildWeb) {
    New-Item -ItemType Directory -Force -Path (Join-Path $Project "builds\web") | Out-Null
    & $Godot --headless --path $Project --export-release "Web" (Join-Path $Project "builds\web\index.html")
    if ($LASTEXITCODE -ne 0) { throw "Web export failed." }
}

if ($BuildWindows) {
    New-Item -ItemType Directory -Force -Path (Join-Path $Project "builds\windows") | Out-Null
    & $Godot --headless --path $Project --export-release "Windows Desktop" (Join-Path $Project "builds\windows\APSRacer.exe")
    if ($LASTEXITCODE -ne 0) { throw "Windows export failed." }
}

if ($BuildAndroid) {
    New-Item -ItemType Directory -Force -Path (Join-Path $Project "builds\android") | Out-Null
    & $Godot --headless --path $Project --export-debug "Android" (Join-Path $Project "builds\android\APSRacer-debug.apk")
    if ($LASTEXITCODE -ne 0) { throw "Android export failed." }
}

Write-Host "APS Racer build complete."
