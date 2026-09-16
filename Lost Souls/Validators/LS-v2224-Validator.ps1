# Get-FileHash "<game folder>\LostSouls.exe" -Algorithm SHA256

# --- Configuration ---
$Version = "2224"
$Title = "Earth2150: Lost Souls v$Version - Validator"
$regPath = "HKCU:\Software\Topware\LostSouls\BaseGame\FileSystem"
$exeName = "LostSouls.exe"

# Set this to the hash matching your specific version
$expectedHash = "B7B770575735837AB5561B6C5BF5785F345F616731372BB392BA3FF4095E1AED"

# --- Defined Patterns ---
$langPattern    = "Language${Version}LS*.wd"
$updatePattern  = "Update${Version}.wd"

# Core files required (excluding the language/update files handled by patterns)
$requiredWDFiles = @(
    "IeoArena_v1.0.wd", "Interface.wd", "InterfaceEx.wd", "Language.wd",
    "Levels.wd", "Meshes.wd", "Parameters.wd", "Players.wd",
    "Scripts.wd", "Sounds.wd", "Terrains.wd", "TerrainsEx.wd",
    "Textures.wd", "Update001.wd", "Wave22kH.wd"
)
$requiredFolders = @("Modules", "Music", "Players", "Video", "WDFiles")
$unwantedFolders = @("Interface", "Language", "Meshes", "Parameters", "Scripts", "Textures")

# Window Title
$host.UI.RawUI.WindowTitle = $Title

# --- Functions ---
Function Write-Status($message, $color) {
    Write-Host ("  " + $message) -ForegroundColor $color
}

Clear-Host
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host $Title -ForegroundColor Green
Write-Host "=======================================================" -ForegroundColor Cyan

# `datapath` can hold several ';' separated entries, each suffixed with '>'
$gamePathProp = Get-ItemProperty -Path $regPath -Name "datapath" -ErrorAction SilentlyContinue
if ($gamePathProp) {
    $targetDir = ($gamePathProp.datapath -split ";" |
        Where-Object { $_.Trim() } |
        Select-Object -First 1).Replace(">", "").Trim().TrimEnd("\", "/")
} else {
    $targetDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    Write-Host "Registry entry not found - falling back to the script location." -ForegroundColor DarkYellow
}

Write-Host "GAME LOCATION: $targetDir" -ForegroundColor Yellow

if (-not (Test-Path $targetDir)) {
    Write-Host "`nGame folder not found - place this script in the game directory and run it again." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    return
}

# 1. Structural & Custom Content Audit
Write-Host "`n[1] Structural & Custom Content Audit:" -ForegroundColor Yellow

foreach ($folder in $requiredFolders) {
    $folderPath = Join-Path $targetDir $folder
    if (Test-Path $folderPath) {
        Write-Host ("  " + $folder.PadRight(22) + ": [OK]") -ForegroundColor Green
    } else {
        Write-Host ("  " + $folder.PadRight(22) + ": [MISSING]") -ForegroundColor Red
    }
}

$allDirs = Get-ChildItem -Path $targetDir -Directory -Recurse -Depth 1
foreach ($folder in $unwantedFolders) {
    $found = $allDirs | Where-Object { $_.Name -ieq $folder }
    foreach ($match in $found) {
        $relPath = $match.FullName.Substring($targetDir.Length).TrimStart("\")
        Write-Host ("  " + $relPath.PadRight(22) + ": [UNWANTED]") -ForegroundColor Red
    }
}

# 2. Official Files Audit
Write-Host "`n[2] Official Files Audit:" -ForegroundColor Yellow
$wdDir = Join-Path $targetDir "WDFiles"

# Enumerate all .wd filenames once as plain strings
$actualFileNames = @(Get-ChildItem -Path $wdDir -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -ieq ".wd" } |
    Select-Object -ExpandProperty Name)

# Check standard required files
foreach ($req in $requiredWDFiles) {
    if ($actualFileNames -icontains $req) {
        Write-Status "$($req.PadRight(25)) : [PRESENT]" Green
    } else {
        Write-Status "$($req.PadRight(25)) : [MISSING]" Red
    }
}

# Match language and update files by pattern against the string array
$langMatchName   = $actualFileNames | Where-Object { $_ -like $langPattern }   | Select-Object -First 1
$updateMatchName = $actualFileNames | Where-Object { $_ -like $updatePattern }  | Select-Object -First 1

if ($langMatchName) {
    Write-Status "$($langMatchName.PadRight(25)) : [PRESENT]" Green
} else {
    Write-Status "$($langPattern.PadRight(25)) : [MISSING]" Red
}

if ($updateMatchName) {
    Write-Status "$($updateMatchName.PadRight(25)) : [PRESENT]" Green
} else {
    Write-Status "$($updatePattern.PadRight(25)) : [MISSING]" Red
}

# Any file that is not in requiredWDFiles AND doesn't match either version pattern is unwanted
$extraFiles = @($actualFileNames | Where-Object {
    ($requiredWDFiles -inotcontains $_) -and
    ($_ -notlike $langPattern) -and
    ($_ -notlike $updatePattern)
})

if ($extraFiles.Count -gt 0) {
    Write-Host "  --- Additional files in WDFiles ---" -ForegroundColor DarkGray
    foreach ($file in $extraFiles) {
        Write-Status "$($file.PadRight(25)) : [UNWANTED]" Red
    }
}

# 3. Custom WD Files Audit
Write-Host "`n[3] Custom WD Files Audit:" -ForegroundColor Yellow
$customDir = Join-Path $targetDir "CustomWDFiles"
if (Test-Path $customDir) {
    Write-Host ("  " + "CustomWDFiles".PadRight(25) + ": [PRESENT]") -ForegroundColor Green
    $customWDs = @(Get-ChildItem -Path $customDir -File | Where-Object { $_.Extension -ieq ".wd" })
    if ($customWDs.Count -gt 0) {
        for ($i = 0; $i -lt $customWDs.Count; $i++) {
            $treeChar = if ($i -eq $customWDs.Count - 1) { "  └───" } else { "  ├───" }
            Write-Host ($treeChar + $customWDs[$i].Name) -ForegroundColor White
        }
    } else {
        Write-Host "  (no .wd files found)" -ForegroundColor DarkGray
    }
} else {
    Write-Host ("  " + "CustomWDFiles".PadRight(25) + ": [NOT PRESENT]") -ForegroundColor DarkGray
}

# 4. Modules Audit
Write-Host "`n[4] Modules Audit:" -ForegroundColor Yellow
$modDir = Join-Path $targetDir "Modules"
if (Test-Path $modDir) {
    $ieoFiles = Get-ChildItem -Path $modDir -File | Where-Object { $_.Extension -ieq ".ieo" }
    foreach ($file in $ieoFiles) {
        Write-Host ("  Module: " + $file.Name.PadRight(35) + "[OK]") -ForegroundColor Green
    }
} else {
    Write-Host "  Modules folder missing!" -ForegroundColor Red
}

# 5. Executable Validation
Write-Host "`n[5] Executable Validation:" -ForegroundColor Yellow
$exePath = Join-Path $targetDir $exeName
if (Test-Path $exePath) {
    $fileVer = (Get-Item $exePath).VersionInfo.FileVersion
    Write-Status "Version: $fileVer" White
    $hash = (Get-FileHash -Path $exePath -Algorithm SHA256).Hash
    if ($hash -ieq $expectedHash) { Write-Status "Hash:  VERIFIED" Green }
    else { Write-Status "Hash:  INVALID (Hash: $hash)" Red }
} else {
    Write-Status "Status:  EXECUTABLE MISSING" Red
}

Write-Host "`n=======================================================" -ForegroundColor Cyan
Read-Host "Press Enter to exit"
