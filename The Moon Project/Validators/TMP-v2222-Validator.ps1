# Get-FileHash "$regPathTheMoonProject.exe" -Algorithm SHA256

# --- Configuration ---
$Version = "2222"
$Title = "Earth2150: The Moon Project v$Version - Validator"
$regPath = "HKCU:\Software\Topware\TheMoonProject\BaseGame\FileSystem"
$exeName = "TheMoonProject.exe"

# Set this to the hash matching your specific version
$expectedHash = "7AD223F801CEF2150C41E5419DEC400FD9B4846BB493EE6F969606ADD6BB176D"

# --- Defined Patterns ---
$langPattern = "Language$VersionTMP*.wd"
$updatePattern = "Update$Version.wd"

# Core files required (excluding the language/update files handled by variables)
$requiredWDFiles = @("Interface.wd", "InterfaceEx.wd", "Language.wd", "Levels.wd", "Meshes.wd", "Parameters.wd", "Players.wd", "Scripts.wd", "Sounds.wd", "Terrains.wd", "TerrainsEx.wd", "Textures.wd", "Update001.wd", "Wave22kH.wd")
$requiredFolders = @("Modules", "Music", "Players", "Video", "WDFiles")
$unwantedFolders = @("Interface", "Language", "Meshes", "Parameters", "Scripts", "Textures")

# Window Title
$host.UI.RawUI.WindowTitle = "$Title"

# --- Functions ---
Function Write-Status($message, $color) {
    Write-Host ("  " + $message) -ForegroundColor $color
}

Clear-Host
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "$Title" -ForegroundColor Green
Write-Host "=======================================================" -ForegroundColor Cyan
 
$gamePathProp = Get-ItemProperty -Path $regPath -Name "datapath" -ErrorAction SilentlyContinue
$targetDir = $gamePathProp.datapath.Replace(">", "").TrimEnd("\")

Write-Host "GAME LOCATION: $targetDir"  -ForegroundColor Yellow
 
# 1. Structural & Custom Content Audit
Write-Host "`n[1] Structural & Custom Content Audit:" -ForegroundColor Yellow
 
# Check required folders
foreach ($folder in $requiredFolders) {
    $folderPath = Join-Path $targetDir $folder
    if (Test-Path $folderPath) {
        Write-Host ("  " + $folder.PadRight(22) + ": [OK]") -ForegroundColor Green
    } else {
        Write-Host ("  " + $folder.PadRight(22) + ": [MISSING]") -ForegroundColor Red
    }
}
 
# Check unwanted folders — including one level of subfolders
$allDirs = Get-ChildItem -Path $targetDir -Directory -Recurse -Depth 1
foreach ($folder in $unwantedFolders) {
    $matches = $allDirs | Where-Object { $_.Name -ieq $folder }
    foreach ($match in $matches) {
        $relPath = $match.FullName.Substring($targetDir.Length).TrimStart("\")
        Write-Host ("  " + $relPath.PadRight(22) + ": [UNWANTED]") -ForegroundColor Red
    }
}
 
# 2. Official Files Audit
Write-Host "`n[2] Official Files Audit:" -ForegroundColor Yellow
$wdDir = Join-Path $targetDir "WDFiles"
$actualFileNames = Get-ChildItem -Path $wdDir -Filter "*.wd" | Select-Object -ExpandProperty Name
 
foreach ($req in $requiredWDFiles) {
    if ($actualFileNames -contains $req) { Write-Status "$($req.PadRight(25)) : [PRESENT]" Green }
    else { Write-Status "$($req.PadRight(25)) : [MISSING]" Red }
}
 
$langMatch = Get-ChildItem -Path $wdDir -Filter $langPattern
if ($langMatch.Count -gt 0) { Write-Status "$($langMatch[0].Name.PadRight(25)) : [PRESENT]" Green }
else { Write-Status "$($langPattern.PadRight(25)) : [MISSING]" Red }
 
if ($actualFileNames -contains $updatePattern) { Write-Status "$($updatePattern.PadRight(25)) : [PRESENT]" Green }
else { Write-Status "$($updatePattern.PadRight(25)) : [MISSING]" Red }
 
# Report any .wd files in WDFiles that are not in the known list
$knownFiles = $requiredWDFiles + $updatePattern
$knownFiles += $langMatch | Select-Object -ExpandProperty Name
foreach ($file in $actualFileNames) {
    if ($knownFiles -notcontains $file) {
        Write-Status "$($file.PadRight(25)) : [UNWANTED]" Red
    }
}
 
# 3. Custom WD Files Audit
Write-Host "`n[3] Custom WD Files Audit:" -ForegroundColor Yellow
$customDir = Join-Path $targetDir "CustomWDFiles"
if (Test-Path $customDir) {
    Write-Host ("  CustomWDFiles          : [PRESENT]") -ForegroundColor Yellow
    $customWDs = Get-ChildItem -Path $customDir -Filter "*.wd"
    if ($customWDs.Count -gt 0) {
        $count = 0
        foreach ($file in $customWDs) {
            $count++
            $treeChar = if ($count -eq $customWDs.Count) { "  └───" } else { "  ├───" }
            Write-Host ($treeChar + $file.Name) -ForegroundColor White
        }
    } else {
        Write-Host "  (no .wd files found)" -ForegroundColor DarkGray
    }
} else {
    Write-Host ("  CustomWDFiles          : [NOT PRESENT]") -ForegroundColor DarkGray
}
 
# 4. Modules & Misplaced Files Audit
Write-Host "`n[4] Modules & Misplaced Files Audit:" -ForegroundColor Yellow
$modDir = Join-Path $targetDir "Modules"
if (Test-Path $modDir) {
    foreach ($file in Get-ChildItem -Path $modDir -Filter "*.ieo") { Write-Status "Module: $($file.Name) [OK]" Green }
}
 
# 5. Executable Validation
Write-Host "`n[5] Executable Validation:" -ForegroundColor Yellow
$exePath = Join-Path $targetDir $exeName
Write-Status "Version: $((Get-Item $exePath).VersionInfo.FileVersion)" White
$hash = (Get-FileHash -Path $exePath -Algorithm SHA256).Hash
if ($hash -eq $expectedHash) { Write-Status "Status:  VERIFIED" Green }
else { Write-Status "Status:  INVALID" Red }
 
Write-Host "`n=======================================================" -ForegroundColor Cyan
Read-Host "Press Enter to exit"