#!/bin/bash

# Check if icoutils is installed
if ! command -v wrestool &> /dev/null; then
    echo "icoutils isn't installed. I need this to check the file version."
    echo "If you hit no then you won't see the file version."
    read -p "Can I install it? (y/n) " choice

    case "$choice" in 
        y|Y ) 
            echo "Installing icoutils..."
            # Adjust the package manager based on the OS (e.g., apt, dnf, pacman)
            sudo apt-get update && sudo apt-get install -y icoutils
            ;;
        * ) 
            echo "The script will proceed to perform a hash check only."
            SKIP_VERSION_CHECK=true
            ;;
    esac
fi

# Logic continues here
if [ "$SKIP_VERSION_CHECK" != true ]; then
    echo "Performing version check..."
    # wrestool -x -t 14 "your_file.exe"
fi

clear

# --- Colors ---
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- Configuration ---
VERSION="2222"
EXE_NAME="TheMoonProject.exe"
EXPECTED_HASH="7AD223F801CEF2150C41E5419DEC400FD9B4846BB493EE6F969606ADD6BB176D"
TARGET_DIR="$PWD"

echo "======================================================="
echo "Earth2150: The Moon Project v$VERSION - Linux Validator"
echo "======================================================="
echo "RUNNING FROM: $TARGET_DIR"

# 1. Structural Audit
echo -e "\n[1] Structural Audit:"
REQUIRED_FOLDERS=("Modules" "Music" "Players" "Video" "WDFiles")
UNWANTED_FOLDERS=("Interface" "Meshes" "Textures" "Language" "WDFiles/Language")

for folder in "${REQUIRED_FOLDERS[@]}"; do
    if [ -d "$TARGET_DIR/$folder" ]; then
        printf "  %-22s : ${GREEN}[OK]${NC}\n" "$folder"
    else
        printf "  %-22s : ${RED}[MISSING]${NC}\n" "$folder"
    fi
done

for folder in "${UNWANTED_FOLDERS[@]}"; do
    if [ -d "$TARGET_DIR/$folder" ]; then
        printf "  %-22s : ${RED}[UNWANTED]${NC}\n" "$folder"
    fi
done

# 2. Official Files Audit
echo -e "\n[2] Official Files Audit:"
WDFILES_DIR="$TARGET_DIR/WDFiles"
REQUIRED_WDS=("Interface.wd" "InterfaceEx.wd" "Language.wd" "Levels.wd" "Meshes.wd" "Parameters.wd" "Players.wd" "Scripts.wd" "Sounds.wd" "Terrains.wd" "TerrainsEx.wd" "Textures.wd" "Update001.wd" "Wave22kH.wd")

# Check standard required files
for file in "${REQUIRED_WDS[@]}"; do
    if [ -f "$WDFILES_DIR/$file" ]; then
        printf "  %-25s : ${GREEN}[PRESENT]${NC}\n" "$file"
    else
        printf "  %-25s : ${RED}[MISSING]${NC}\n" "$file"
    fi
done

# Check Language pattern (e.g., Language2222TMP*.wd)
LANG_FILE=$(find "$WDFILES_DIR" -maxdepth 1 -name "Language${VERSION}TMP*.wd" -print -quit)
if [ -n "$LANG_FILE" ]; then
    printf "  %-25s : ${GREEN}[PRESENT]${NC}\n" "$(basename "$LANG_FILE")"
else
    printf "  %-25s : ${RED}[MISSING]${NC}\n" "Language${VERSION}TMP*.wd"
fi

# Check Update pattern (e.g., Update2222.wd)
UPDATE_FILE=$(find "$WDFILES_DIR" -maxdepth 1 -name "Update${VERSION}.wd" -print -quit)
if [ -n "$UPDATE_FILE" ]; then
    printf "  %-25s : ${GREEN}[PRESENT]${NC}\n" "$(basename "$UPDATE_FILE")"
else
    printf "  %-25s : ${RED}[MISSING]${NC}\n" "Update${VERSION}.wd"
fi

# Scan for any additional .wd files not in the required list or pattern-matched files
echo "  --- Additional files in WDFiles ---"
KNOWN_FILES=("${REQUIRED_WDS[@]}")
[ -n "$LANG_FILE" ] && KNOWN_FILES+=("$(basename "$LANG_FILE")")
[ -n "$UPDATE_FILE" ] && KNOWN_FILES+=("$(basename "$UPDATE_FILE")")

while IFS= read -r -d '' found_file; do
    fname="$(basename "$found_file")"
    already_known=false
    for known in "${KNOWN_FILES[@]}"; do
        if [ "$fname" == "$known" ]; then
            already_known=true
            break
        fi
    done
    if [ "$already_known" = false ]; then
        printf "  %-25s : ${RED}[UNWANTED]${NC}\n" "$fname"
    fi
done < <(find "$WDFILES_DIR" -maxdepth 1 -name "*.wd" -print0 | sort -z)

# 3. Custom WD Files Audit
echo -e "\n[3] Custom WD Files Audit:"
CUSTOM_DIR="$TARGET_DIR/CustomWDFiles"
if [ -d "$CUSTOM_DIR" ]; then
    printf "  %-25s : ${GREEN}[PRESENT]${NC}\n" "CustomWDFiles"
    # List all .wd files inside, with tree-style prefix
    mapfile -d '' custom_files < <(find "$CUSTOM_DIR" -maxdepth 1 -name "*.wd" -print0 | sort -z)
    total=${#custom_files[@]}
    for i in "${!custom_files[@]}"; do
        fname="$(basename "${custom_files[$i]}")"
        if [ $((i + 1)) -eq $total ]; then
            printf "    ${GREEN}└─${NC}%s\n" "$fname"
        else
            printf "    ${GREEN}├─${NC}%s\n" "$fname"
        fi
    done
    if [ $total -eq 0 ]; then
        echo -e "    ${RED}No .wd files found in CustomWDFiles${NC}"
    fi
else
    printf "  %-25s : ${RED}[MISSING]${NC}\n" "CustomWDFiles"
fi

# 4. Modules Audit
echo -e "\n[4] Modules Audit:"
MOD_DIR="$TARGET_DIR/Modules"
if [ -d "$MOD_DIR" ]; then
    find "$MOD_DIR" -maxdepth 1 -name "*.ieo" -print0 | while IFS= read -r -d '' file; do
        printf "  Module: %-30s ${GREEN}[OK]${NC}\n" "$(basename "$file")"
    done
else
    echo -e "  ${RED}Modules folder missing!${NC}"
fi

# 5. Executable Validation (WSL-optimized)
echo -e "\n[5] Executable Validation:"
if [ -f "$TARGET_DIR/$EXE_NAME" ]; then
    FILE_VER=$(wrestool -x --raw --type=16 --name=1 --language=0 "$TARGET_DIR/$EXE_NAME" 2>/dev/null | \
      dd bs=1 skip=48 count=8 2>/dev/null | \
      od -A n -t u2 | \
      awk '{printf "%d.%d.%d.%d\n", $2, $1, $4, $3}')
    echo "  Version: ${FILE_VER:-Unknown}"
    HASH=$(sha256sum "$TARGET_DIR/$EXE_NAME" | cut -d ' ' -f 1)
    if [ "${HASH,,}" == "${EXPECTED_HASH,,}" ]; then
        echo -e "  Status:  ${GREEN}VERIFIED${NC}"
    else
        echo -e "  Status:  ${RED}INVALID${NC} (Hash: $HASH)"
    fi
else
    echo -e "  Status:  ${RED}EXECUTABLE MISSING${NC}"
fi

echo -e "\n======================================================="
read -p "Press Enter to exit"