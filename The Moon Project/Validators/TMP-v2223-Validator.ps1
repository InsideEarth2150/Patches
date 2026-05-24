# Get-FileHash "$regPathTheMoonProject.exe" -Algorithm SHA256

# --- Configuration ---
$Version = "2223"
$Title = "Earth2150: The Moon Project v$Version - Validator"
$regPath = "HKCU:\Software\Topware\TheMoonProject\BaseGame\FileSystem"
$exeName = "TheMoonProject.exe"

# Set this to the hash matching your specific version
$expectedHash = "2A130D074536B224F2952AB66E615F25DB1A8797522E05E2A7FC92C780F99E25"

# --- Defined Patterns ---
$langPattern = "Language$VersionTMP*.wd"
$updatePattern = "Update$Version.wd"

# Core files required (excluding the language/update files handled by patterns)
$requiredWDFiles = @(
    "Interface.wd", "InterfaceEx.wd", "Language.wd", "Levels.wd",
    "Meshes.wd", "Parameters.wd", "Players.wd", "Scripts.wd",
    "Sounds.wd", "Terrains.wd", "TerrainsEx.wd", "Textures.wd",
    "Update001.wd", "Wave22kH.wd"
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

$gamePathProp = Get-ItemProperty -Path $regPath -Name "datapath" -ErrorAction SilentlyContinue
$targetDir = $gamePathProp.datapath.Replace(">", "").TrimEnd("\").TrimEnd("/")

Write-Host "GAME LOCATION: $targetDir" -ForegroundColor Yellow

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
$actualFileNames = @(Get-ChildItem -Path $wdDir -File |
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
$extraFiles = $actualFileNames | Where-Object {
    ($requiredWDFiles -inotcontains $_) -and
    ($_ -notlike $langPattern) -and
    ($_ -notlike $updatePattern)
}

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