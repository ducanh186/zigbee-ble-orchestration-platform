#!/usr/bin/env bash
# Headless build / flash / verify for end-device kits (no Simplicity Studio).
#
#   kit.sh learn  <kit>        plug ONE board; detect + remember its J-Link serial
#   kit.sh build  <kit|all>    slc generate + make -> artifact/<kit>/<kit>.s37
#   kit.sh flash  <kit|all>    commander flash by remembered serial (no mass-erase)
#   kit.sh verify <kit|all>    functional verify over MQTT (watches /tmp/z3gw.log)
#   kit.sh all                 build + flash + verify each kit with a connected serial
#
# Requires: scripts/setup-silabs-toolchain.sh run once (writes testing_tools/.silabs-env).
# NOTE: slc flag names vary by slc-cli version — if `slc generate` fails, check
# `slc generate --help` and adjust build_kit(), then record the working command.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$REPO_ROOT"
ENV_FILE="testing_tools/.silabs-env"
[ -f "$ENV_FILE" ] || { echo "ERROR: $ENV_FILE missing — run scripts/setup-silabs-toolchain.sh first"; exit 1; }
# shellcheck disable=SC1090
source "$ENV_FILE"   # SLC, ARM_TOOLCHAIN, COMMANDER, SDK, JRE_BIN
# slc-cli is a Java app — ensure its JRE is on PATH.
[ -n "${JRE_BIN:-}" ] && export PATH="$JRE_BIN:$PATH"
# slc needs the Studio adapter packs (ZAP) to generate ZCL config (zap-config.h).
[ -n "${ADAPTER_PACKS:-}" ] && export STUDIO_ADAPTER_PACK_PATH="$ADAPTER_PACKS"

MANIFEST="testing_tools/kits.manifest"
KITS_BUILD_ROOT="${KITS_BUILD_ROOT:-$HOME/ss_v5/kits}"

# ---- manifest helpers (fields: 1=kit 2=slcp 3=part 4=board 5=jlink 6=verify) ----
row()       { grep -E "^$1\|" "$MANIFEST" || true; }
field()     { row "$1" | head -1 | cut -d'|' -f"$2"; }
kits_all()  { grep -vE '^\s*#' "$MANIFEST" | grep -vE '^\s*$' | cut -d'|' -f1; }
known_kit() { [ -n "$(field "$1" 2)" ]; }

connected_serials() { "$COMMANDER" adapter list 2>/dev/null | sed -nE 's/^\s*serialNumber=([0-9]+).*/\1/p'; }

# ---- build: in-place slc generate + zap-cli + make -> artifact ----
# slc-cli (5.11) does NOT run ZAP during generate, so its Makefile omits the
# ZAP ZCL sources (zap-cluster-command-parser.c / zap-cli.c / zap-event.c) that
# define decoders + cluster tick callbacks. We generate them with zap-cli and
# inject their compile/link rules into the project.mak. Build runs IN the
# project dir (so app/*.h resolve); autogen/config churn + generated Makefiles
# + build/ are cleaned afterwards (only artifact/<kit>/<kit>.s37 persists).
build_kit() {
  local kit="$1" slcp part board P zapf mk zc b
  known_kit "$kit" || { echo "unknown kit: $kit"; return 1; }
  slcp="$(field "$kit" 2)"; part="$(field "$kit" 3)"; board="$(field "$kit" 4)"
  P="$(dirname "$slcp")"

  echo "[$kit] slc generate (in-place)"
  "$SLC" generate -p "$slcp" -d "$P" --sdk "$SDK" --toolchain toolchain_gcc \
    -o makefile --with "$part,brd4001a,$board" --force

  zapf="$(ls "$P"/config/zcl/*.zap 2>/dev/null | head -1)"
  if [ -n "$zapf" ]; then
    echo "[$kit] zap-cli generate (ZCL) + inject into Makefile"
    "$ADAPTER_PACKS/zap/zap-cli" generate --noUi --noServer \
      --gen "$SDK/protocol/zigbee/app/framework/gen-template/gen-templates.json" \
      --in "$zapf" --out "$P/autogen"
    mk="$P/$kit.project.mak"
    {
      echo ''
      echo '# --- injected by kit.sh: ZAP sources slc-cli omits ---'
      for zc in "$P"/autogen/zap-*.c; do
        [ -f "$zc" ] || continue
        b="$(basename "$zc")"
        grep -q "autogen/$b" "$mk" && continue
        echo "\$(OUTPUT_DIR)/project/autogen/${b%.c}.o: autogen/$b"
        printf '\t%s\n' '@$(POSIX_TOOL_PATH)mkdir -p $(@D)'
        printf '\t%s\n' "\$(ECHO)\$(CC) \$(CFLAGS) -c -o \$@ autogen/$b"
        echo "OBJS += \$(OUTPUT_DIR)/project/autogen/${b%.c}.o"
      done
    } >> "$mk"
  fi

  echo "[$kit] make (GNU ARM 12.2.1)"
  ( cd "$P" && PATH="$ARM_TOOLCHAIN/bin:$PATH" make -f "$kit.Makefile" -j"$(nproc)" )

  mkdir -p "$REPO_ROOT/artifact/$kit"
  cp "$P/build/debug/$kit.s37" "$REPO_ROOT/artifact/$kit/$kit.s37"
  echo "[$kit] artifact -> artifact/$kit/$kit.s37"

  # Keep repo at source-of-truth: autogen/config are tracked & regenerated;
  # generated Makefiles + build/ are transient. (.slcp + artifact/ persist.)
  git -C "$REPO_ROOT" restore "$P/autogen" "$P/config" "$P/.cproject" "$P/.project" 2>/dev/null || true
  rm -f "$P/$kit.Makefile" "$P/$kit.project.mak"
  rm -rf "$P/build"
  git -C "$REPO_ROOT" clean -fdq "$P" 2>/dev/null || true
  echo "[$kit] cleaned build churn"
}

# ---- learn: record the single connected J-Link serial into the manifest ----
learn_kit() {
  local kit="$1"; known_kit "$kit" || { echo "unknown kit: $kit"; return 1; }
  local serials; mapfile -t serials < <(connected_serials)
  [ "${#serials[@]}" -eq 1 ] || {
    echo "ERROR: need exactly 1 J-Link connected, found ${#serials[@]}: ${serials[*]:-none}"; return 1; }
  local s="${serials[0]}"
  awk -F'|' -v OFS='|' -v k="$kit" -v s="$s" '($1==k){$5=s} {print}' "$MANIFEST" > "$MANIFEST.tmp" \
    && mv "$MANIFEST.tmp" "$MANIFEST"
  echo "learned: $kit -> J-Link $s   (also tell Claude to mirror this into memory)"
}

# ---- flash: by remembered serial, no mass-erase (preserve token+NVM3) ----
flash_kit() {
  local kit="$1" jlink art; known_kit "$kit" || { echo "unknown kit: $kit"; return 1; }
  jlink="$(field "$kit" 5)"; art="$REPO_ROOT/artifact/$kit/$kit.s37"
  [ -n "$jlink" ] || { echo "[$kit] no J-Link serial learned (run: kit.sh learn $kit)"; return 1; }
  [ -f "$art" ]   || { echo "[$kit] artifact missing: $art (run: kit.sh build $kit)"; return 1; }
  if ! connected_serials | grep -qx "$jlink"; then echo "[$kit] SKIP: board $jlink not connected"; return 2; fi
  echo "[$kit] flashing $art -> J-Link $jlink (no masserase)"
  "$COMMANDER" flash "$art" --serialno "$jlink"
  "$COMMANDER" verify "$art" --serialno "$jlink"
  "$COMMANDER" device reset --serialno "$jlink"
}

# ---- verify: functional signal over MQTT (watch gateway log) ----
verify_kit() {
  local kit="$1" kind pat hint; known_kit "$kit" || { echo "unknown kit: $kit"; return 1; }
  kind="$(field "$kit" 6)"
  case "$kind" in
    environment) pat='devices/sensor/.*/reported|ENV.*report';                       hint="DHT11 reports automatically";;
    light)       pat='REG.*paired.*light|tc_join|LIGHT.*executed_tx';                 hint="after join, controller sends device.command on/off";;
    switch)      pat='devices/switch/.*/event|tc_join';                               hint="PRESS the switch button now";;
    occupancy)   pat='occupancy|devices/(sensor|motion)/.*/(event|reported)|tc_join'; hint="TRIGGER motion now";;
    *) echo "[$kit] unknown verify kind: $kind"; return 1;;
  esac
  echo "[$kit] verify ($kind), up to 120s — $hint"
  if timeout 120 stdbuf -oL tail -n0 -f /tmp/z3gw.log 2>/dev/null | stdbuf -oL grep -m1 -E "$pat"; then
    echo "[$kit] VERIFY PASS"
  else
    echo "[$kit] VERIFY FAIL (no signal in 120s)"; return 1
  fi
}

main() {
  local cmd="${1:-}"; shift || true
  case "$cmd" in
    learn)  for k in "$@"; do learn_kit "$k"; done ;;
    build)  if [ "${1:-}" = all ] || [ $# -eq 0 ]; then for a in $(kits_all); do build_kit "$a"; done
            else for k in "$@"; do build_kit "$k"; done; fi ;;
    flash)  if [ "${1:-}" = all ] || [ $# -eq 0 ]; then for a in $(kits_all); do flash_kit "$a" || true; done
            else for k in "$@"; do flash_kit "$k"; done; fi ;;
    verify) if [ "${1:-}" = all ] || [ $# -eq 0 ]; then for a in $(kits_all); do verify_kit "$a" || true; done
            else for k in "$@"; do verify_kit "$k"; done; fi ;;
    all)    for k in $(kits_all); do
              echo "==== $k ===="
              build_kit "$k" || { echo "[$k] build FAILED"; continue; }
              flash_kit "$k" || { echo "[$k] flash skipped/failed"; continue; }
              verify_kit "$k" || echo "[$k] verify FAILED"
            done ;;
    *) echo "usage: kit.sh {learn|build|flash|verify|all} <kit|all>"; exit 2 ;;
  esac
}
main "$@"
