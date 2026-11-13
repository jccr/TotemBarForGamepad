#!/bin/sh
# Offline tests for Totem Bar for Gamepad.
#   ./run-all.sh [addon dir]    (default: ../src)
cd "$(dirname "$0")" || exit 1
ADDON=${1:-../src}
KIT="$ADDON/GamepadKit"
TOC=$(ls "$ADDON"/*.toc 2>/dev/null | head -1)
[ -d node_modules ] || npm install --silent || exit 1
echo "Testing: $ADDON"
fail=0
step() { # name, command...
  name=$1; shift
  out=$("$@" 2>&1); status=$?
  if [ $status -ne 0 ] || printf '%s\n' "$out" | grep -qE '^(FAIL|ERR)|Error:'; then
    echo "FAIL  $name"; printf '%s\n' "$out" | sed 's/^/      /'; fail=$((fail + 1))
  else
    echo "ok    $name"; [ -n "$VERBOSE" ] && printf '%s\n' "$out" | sed 's/^/      /'
  fi
}
step "parse (files + snippets)" node checks/parse.js "$ADDON"
for f in "$ADDON"/*.lua "$KIT"/*.lua; do
  step "locals  ${f#$ADDON/}" node checks/locals.js "$f"
  step "globals ${f#$ADDON/}" node checks/globals.js "$f" "$TOC"
done
step "grid snippets" node checks/snippets.js "$KIT" "$ADDON/TotemBarFocus.lua"
for s in sim/scenarios/*.lua; do
  step "sim $(basename "$s" .lua)" node sim/run.js "$KIT" "$s"
done
step "full load" node fullload.js "$ADDON"
echo
[ $fail -eq 0 ] && echo "All passed." || echo "$fail failed."
exit $fail
