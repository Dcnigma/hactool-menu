#!/bin/bash

### REQUIREMENTS ###
command -v dialog >/dev/null || { echo "Install dialog first (brew install dialog)"; exit 1; }
command -v zip >/dev/null || { echo "Install zip first (brew install zip)"; exit 1; }

### TOOLS ###
HACTOOL="./hactool"
KEYS="./prod.keys"

### GLOBALS ###
WORK=""
BASE=""
MERGED_ROMFS=""
LOGFILE=""

### CLEANUP ###
trap "rm -f /tmp/menu.$$" EXIT

### ---------- LOGGING ----------
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}

fail_msg() {
  dialog --msgbox "❌ $1\n\nSee log:\n$LOGFILE" 8 60
}

### ---------- CORE FUNCTIONS ----------
extract_container() {
  FILE=$(dialog --inputbox "Enter NSP/XCI path:" 8 60 2>&1 >/dev/tty)
  [[ ! -f "$FILE" ]] && return

  BASE="$(basename "${FILE%.*}")"
  WORK="${BASE}_workspace"
  LOGFILE="$WORK/toolkit.log"

  mkdir -p "$WORK"/{container,ncas/{base,patch,dlc},merged/romfs,staging,mods,info,exports}
  : > "$LOGFILE"

  log "Extracting container: $FILE"
  "$HACTOOL" -k "$KEYS" -t pfs0 --pfs0dir="$WORK/container" "$FILE" >>"$LOGFILE" 2>&1

  extract_ncas
}

extract_ncas() {
  for NCA in "$WORK/container"/*.nca; do
    NAME=$(basename "$NCA" .nca)
    TMP="$WORK/ncas/tmp_$NAME"
    mkdir -p "$TMP"/{RomFS,ExeFS}

    log "Extracting NCA $NAME"
    "$HACTOOL" -k "$KEYS" \
      --romfsdir="$TMP/RomFS" \
      --exefsdir="$TMP/ExeFS" \
      "$NCA" >>"$LOGFILE" 2>&1

    if [[ -f "$TMP/ExeFS/main" || -f "$TMP/ExeFS/main.npdm" ]]; then
      if [[ -f "$TMP/RomFS/patch.nca" ]]; then
        mv "$TMP" "$WORK/ncas/patch/$NAME"
      else
        mv "$TMP" "$WORK/ncas/base/$NAME"
      fi
    else
      mv "$TMP" "$WORK/ncas/dlc/$NAME"
    fi
  done

  merge_romfs
}

merge_romfs() {
  MERGED_ROMFS="$WORK/merged/romfs"
  rm -rf "$MERGED_ROMFS"
  mkdir -p "$MERGED_ROMFS"

  for DIR in "$WORK/ncas/base/"*/RomFS "$WORK/ncas/patch/"*/RomFS "$WORK/ncas/dlc/"*/RomFS; do
    [[ -d "$DIR" ]] && rsync -a "$DIR/" "$MERGED_ROMFS/" >>"$LOGFILE" 2>&1
  done

  dialog --msgbox "RomFS merged successfully" 6 40
}

### ---------- BROWSE + STAGE ----------
browse_staging() {
  [[ ! -d "$MERGED_ROMFS" ]] && { dialog --msgbox "Merged RomFS not found." 7 50; return; }

  while true; do
    TYPE=$(dialog --menu "Select staging type:" 10 50 3 \
      1 "RomFS" \
      2 "ExeFS" \
      0 "Back" \
      2>&1 >/dev/tty)

    [[ "$TYPE" == "0" || -z "$TYPE" ]] && break

    case $TYPE in
      1) SRC="$MERGED_ROMFS"; DEST_BASE="$WORK/staging/romfs" ;;
      2)
        EXEFS_DIRS=()
        for DIR in "$WORK/ncas/base/"*/ExeFS "$WORK/ncas/patch/"*/ExeFS "$WORK/ncas/dlc/"*/ExeFS; do
          [[ -d "$DIR" ]] && EXEFS_DIRS+=("$DIR")
        done
        [[ ${#EXEFS_DIRS[@]} -eq 0 ]] && { dialog --msgbox "No ExeFS found." 6 40; continue; }
        MENU_ITEMS=()
        for i in "${!EXEFS_DIRS[@]}"; do
          MENU_ITEMS+=("$i" "$(basename "${EXEFS_DIRS[$i]}")")
        done
        CHOICE=$(dialog --menu "Select ExeFS:" 20 70 10 "${MENU_ITEMS[@]}" 2>&1 >/dev/tty)
        [[ -z "$CHOICE" ]] && continue
        SRC="${EXEFS_DIRS[$CHOICE]}"
        DEST_BASE="$WORK/staging/exefs"
        ;;
    esac

    FILE=$(dialog --fselect "$SRC/" 20 80 2>&1 >/dev/tty)
    [[ -z "$FILE" ]] && continue

    REL="${FILE#$SRC/}"
    DEST="$DEST_BASE/$REL"
    mkdir -p "$(dirname "$DEST")"

    if [[ -d "$FILE" ]]; then
      rsync -a "$FILE/" "$DEST/" >>"$LOGFILE" 2>&1
    else
      cp "$FILE" "$DEST" >>"$LOGFILE" 2>&1
    fi

    dialog --msgbox "Copied:\n$REL" 7 60
  done
}

### ---------- SYNC MOD ----------
sync_mod() {
  PROFILE=$(dialog --inputbox "Mod profile name:" 8 40 2>&1 >/dev/tty)
  [[ -z "$PROFILE" ]] && return

  MOD="$WORK/mods/$PROFILE"
  mkdir -p "$MOD"/{romfs,exefs}

  rsync -a "$WORK/staging/romfs/" "$MOD/romfs/" >>"$LOGFILE" 2>&1
  rsync -a "$WORK/staging/exefs/" "$MOD/exefs/" >>"$LOGFILE" 2>&1

  dialog --msgbox "Profile synced: $PROFILE" 6 50
}

### ---------- TITLE DETECTION ----------
detect_title() {
  log "Detecting TITLEID"
  mkdir -p "$WORK/info"

  CNMT=$(find "$WORK/container" -name "*.cnmt.xml" | head -n1)

  if [[ -f "$CNMT" ]]; then
    TITLEID=$(grep -Eo '<Id>[^<]+' "$CNMT" | head -1 | sed 's/<Id>//')
    log "Detected TITLEID=$TITLEID"
  fi

  if [[ -z "$TITLEID" ]]; then
    TITLEID=$(dialog --inputbox "Enter TITLEID:" 8 50 2>&1 >/dev/tty)
  fi

  [[ -z "$TITLEID" ]] && return
  echo "$TITLEID" > "$WORK/info/titleid.txt"
}

### ---------- EXPORT ATMOSPHERE ZIP ----------
export_atmosphere() {
    PROFILE=$(dialog --inputbox "Profile to export:" 8 50 2>&1 >/dev/tty)
    [[ -z "$PROFILE" ]] && return

    MOD="$WORK/mods/$PROFILE"
    [[ ! -d "$MOD" ]] && { fail_msg "Profile '$PROFILE' not found"; return; }

    TITLEID=$(cat "$WORK/info/titleid.txt" 2>/dev/null)
    [[ -z "$TITLEID" ]] && detect_title
    TITLEID=$(cat "$WORK/info/titleid.txt" 2>/dev/null)

    [[ -z "$TITLEID" ]] && { fail_msg "TITLEID missing"; return; }

    TMP="$WORK/exports/tmp"
    ATMOS_DIR="$TMP/atmosphere/contents/$TITLEID"
    ZIPNAME="${PROFILE}.zip"
    OUTZIP="$WORK/exports/$ZIPNAME"

    log "Exporting profile '$PROFILE' for TITLEID=$TITLEID"

    rm -rf "$TMP"
    mkdir -p "$ATMOS_DIR"

    # Copy from profile
    [[ -d "$MOD/romfs" ]] && rsync -a "$MOD/romfs/" "$ATMOS_DIR/romfs/" >>"$LOGFILE" 2>&1
    [[ -d "$MOD/exefs" ]] && rsync -a "$MOD/exefs/" "$ATMOS_DIR/exefs/" >>"$LOGFILE" 2>&1

    if [[ ! -d "$ATMOS_DIR/romfs" && ! -d "$ATMOS_DIR/exefs" ]]; then
        rm -rf "$TMP"
        fail_msg "Nothing to export (romfs/exefs empty)"
        return
    fi

    dialog --infobox "Creating Atmosphère ZIP..." 5 50

    mkdir -p "$WORK/exports"
    rm -f "$OUTZIP"

    # ✅ ZIP MUST BE CREATED INSIDE TMP
    (
        cd "$TMP" || exit 1
        /usr/bin/zip -r "$ZIPNAME" atmosphere
    ) >>"$LOGFILE" 2>&1

    if [[ ! -f "$TMP/$ZIPNAME" ]]; then
        log "ZIP FAILED — dumping tree"
        find "$TMP" >>"$LOGFILE"
        rm -rf "$TMP"
        fail_msg "ZIP creation failed"
        return
    fi

    mv "$TMP/$ZIPNAME" "$OUTZIP"

    rm -rf "$TMP"

    dialog --msgbox "✅ ZIP created successfully:\n$OUTZIP" 8 60
}


### ---------- MAIN MENU ----------
while true; do
  CHOICE=$(dialog --menu "Switch LayeredFS Mod Toolkit" 20 60 10 \
    1 "Extract NSP/XCI" \
    2 "Browse + Stage" \
    3 "Sync staging → profile" \
    4 "Export Atmosphère ZIP" \
    0 "Exit" \
    2>&1 >/dev/tty)

  case $CHOICE in
    1) extract_container ;;
    2) browse_staging ;;
    3) sync_mod ;;
    4) export_atmosphere ;;
    0) clear; exit ;;
  esac
done
