#!/bin/bash
# avinstallera.sh – tar bort AttGöra och alla spår av den.
#
#   ./avinstallera.sh [attgora] [--dry-run] [--delete-data] [--no-backup] [--yes]
#
#   --dry-run       visar bara vad som skulle tas bort, ändrar ingenting
#   --delete-data   tar även bort dina uppgifter (todos.json)
#                   Utan flaggan frågar skriptet separat om datan.
#   --no-backup     hoppa över zip-säkerhetskopian av datan på skrivbordet
#   --yes           fråga inte efter bekräftelse (datan frågas ändå om, om inte --delete-data)
#
# Generell app: ./avinstallera.sh --generic "Appnamn" bundle.id [DataMapp ...]
# Det gör samma sak men utan appspecifika extra spår.


# Kör en kopia av sig själv, så att skriptet kan ta bort sin egen mapp utan problem.
if [ -z "${AVINST_COPY:-}" ]; then
  T="$(mktemp /tmp/avinstallera.XXXXXX)"; cp "$0" "$T"; AVINST_COPY=1 exec bash "$T" "$@"
fi
DEFAULT_APP="attgora"
LIB="$HOME/Library"
APPS="$HOME/Applications"
DRY=0; DELDATA=0; BACKUP=1; YES=0; GENERIC=0
NAME=""; BUNDLES=(); DATADIRS=(); EXTRAS=(); SOURCE=""; PROCS=()

list() {
  echo "attgora"
}

# ---- appens definition ----
define() {
  case "$1" in
    attgora)
      NAME="AttGöra"; BUNDLES=(se.gustavlundstrom.todo)
      PROCS=(AttGora Todo)
      DATADIRS=("$LIB/Application Support/Todo")             # todos.json
      SOURCE="$APPS/AttGöra-källkod"
      EXTRAS=("$APPS/AttGöra för Mac" "$APPS/AttGöra för Mac.zip"
              "$APPS/Todo.app" "$HOME/Desktop/Todo.app" "$APPS/Todo-källkod"
              "$APPS/Todo för Mac" "$APPS/Todo för Mac.zip") ;;
    *) return 1 ;;
  esac
}

# ---- argument ----
ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --delete-data) DELDATA=1 ;;
    --no-backup) BACKUP=0 ;;
    --yes) YES=1 ;;
    --list) list; exit 0 ;;
    --generic) GENERIC=1 ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) ARGS+=("$1") ;;
  esac
  shift
done

if [ $GENERIC = 1 ]; then
  [ ${#ARGS[@]} -ge 2 ] || { echo "Använd: --generic \"Appnamn\" bundle.id [DataMapp ...]"; exit 1; }
  NAME="${ARGS[0]}"; BUNDLES=("${ARGS[1]}"); PROCS=("$NAME")
  for ((i=2; i<${#ARGS[@]}; i++)); do DATADIRS+=("${ARGS[$i]}"); done
  SOURCE="$APPS/$NAME-källkod"
else
  [ ${#ARGS[@]} -eq 0 ] && [ -n "$DEFAULT_APP" ] && ARGS=("$DEFAULT_APP")
  [ ${#ARGS[@]} -eq 1 ] || { echo "Använd: $0 <app> [flaggor]   (se --list)"; exit 1; }
  define "$(echo "${ARGS[0]}" | tr 'A-Z' 'a-z')" || { echo "Okänd app: ${ARGS[0]}"; list; exit 1; }
fi

run() { if [ $DRY = 1 ]; then echo "   [dry-run] $*"; else "$@"; fi; }
rmpath() {  # tar bort fil, mapp eller symlänk om den finns
  local p="$1"
  if [ -e "$p" ] || [ -L "$p" ]; then echo "   - $p"; run rm -rf "$p"; FOUND=$((FOUND+1)); fi
}

FOUND=0
echo "== Avinstallerar $NAME ${DRY:+}$([ $DRY = 1 ] && echo '(dry-run)')"
if [ $YES = 0 ] && [ $DRY = 0 ]; then
  read -r -p "Fortsätta? (j/N) " a; [ "$a" = j ] || [ "$a" = J ] || { echo "Avbrutet."; exit 0; }
fi

# 1. Avsluta appen och ta bort inloggningsobjekt/bakgrundstjänster
echo "1. Avslutar processer och bakgrundstjänster"
for p in "${PROCS[@]}"; do
  if pgrep -x "$p" >/dev/null 2>&1; then echo "   avslutar $p"; run pkill -x "$p"; fi
done
for b in "${BUNDLES[@]}"; do
  if launchctl list 2>/dev/null | grep -q "$b"; then
    echo "   stoppar launchd-jobb $b"; run launchctl bootout "gui/$(id -u)/$b" 2>/dev/null
  fi
  # inloggningsobjekt i Systeminställningar
  if osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null | grep -qi "$NAME"; then
    echo "   tar bort inloggningsobjekt $NAME"
    run osascript -e "tell application \"System Events\" to delete login item \"$NAME\"" 2>/dev/null
  fi
done
[ $DRY = 1 ] || sleep 1

# 2. Appen, genvägar, källkod
echo "2. Appen, genvägar och källkod"
rmpath "$APPS/$NAME.app"
rmpath "/Applications/$NAME.app"
rmpath "$HOME/Desktop/$NAME.app"
rmpath "$SOURCE"
for e in "${EXTRAS[@]}"; do rmpath "$e"; done

# 3. Standardmappar i ~/Library för varje bundle-id (rensar även varianter som .binarycookies/.plist)
echo "3. Inställningar, cacher och lagring i ~/Library"
for b in "${BUNDLES[@]}"; do
  for d in Preferences Caches WebKit HTTPStorages Containers "Group Containers" \
           "Application Support" "Saved Application State" Logs Cookies \
           "Application Scripts" LaunchAgents "Preferences/ByHost"; do
    for hit in "$LIB/$d/$b"*; do rmpath "$hit"; done
  done
  # kvitton/permissions-spår
  for hit in "$HOME/Library/Logs/DiagnosticReports/$NAME"*; do rmpath "$hit"; done
  if [ $DRY = 0 ]; then
    defaults delete "$b" >/dev/null 2>&1
    killall cfprefsd >/dev/null 2>&1            # töm cachade inställningar
    tccutil reset All "$b" >/dev/null 2>&1      # nollställ Kamera/Filer/Notiser-behörigheter
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$APPS/$NAME.app" >/dev/null 2>&1
  fi
done

# 4. Din egen data – frågas separat
if [ ${#DATADIRS[@]} -gt 0 ]; then
  EXIST=()
  for d in "${DATADIRS[@]}"; do [ -e "$d" ] && EXIST+=("$d"); done
  if [ ${#EXIST[@]} -gt 0 ]; then
    echo "4. Din data (kan inte ångras):"
    printf '   * %s\n' "${EXIST[@]}"
    GO=$DELDATA
    if [ $GO = 0 ] && [ $DRY = 0 ]; then
      read -r -p "   Ta bort datan också? (j/N) " a; [ "$a" = j ] || [ "$a" = J ] && GO=1
    fi
    if [ $DRY = 1 ]; then GO=1; fi
    if [ $GO = 1 ]; then
      if [ $BACKUP = 1 ] && [ $DRY = 0 ]; then
        Z="$HOME/Desktop/$NAME-data-$(date +%Y%m%d-%H%M).zip"
        zip -rq "$Z" "${EXIST[@]}" 2>/dev/null && echo "   säkerhetskopia: $Z (radera den när du är säker)"
      fi
      for d in "${EXIST[@]}"; do rmpath "$d"; done
    else
      echo "   Datan lämnades kvar."
    fi
  fi
fi

# 5. Slutkontroll
echo "5. Slutkontroll"
LEFT=0
for b in "${BUNDLES[@]}"; do
  [ $DRY = 1 ] && break
  while IFS= read -r f; do echo "   kvar: $f"; LEFT=$((LEFT+1)); done < <(
    find "$LIB" -maxdepth 3 -iname "*$b*" 2>/dev/null
  )
done
if [ $DRY = 1 ]; then echo "Dry-run klar: $FOUND objekt skulle tas bort."
elif [ $LEFT = 0 ]; then echo "Klart: $FOUND objekt borttagna, inga spår kvar i ~/Library."
else echo "Klart, men $LEFT spår hittades (se ovan)."; fi

cat <<EOF

Kan inte tas bort av skriptet:
 - Kopior av appen som du delat med andra.
 - Systembehörigheter som kräver administratör (/Library) – kontrollera med: ls /Library/LaunchDaemons | grep -i "$NAME"
EOF
