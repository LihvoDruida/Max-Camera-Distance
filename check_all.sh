#!/usr/bin/env bash
# Full pre-release gate. Every probe must be wired in here; a check that only
# exists as a file is a check that does not run.
#
# Exit status is the number of failed stages. Note the pipefail/no-tail rule:
# never pipe a probe through head/tail/tee without pipefail, or the pipeline
# reports the LAST command's status and a failing probe passes silently.
set -uo pipefail

cd "$(dirname "$0")"

failures=0

stage() {
    local label="$1"; shift
    echo ""
    echo "=== ${label}"
    if "$@"; then
        echo "--- PASS: ${label}"
    else
        echo "--- FAIL: ${label}"
        failures=$((failures + 1))
    fi
}

lua_syntax() {
    if ! command -v luac5.1 >/dev/null 2>&1; then
        echo "luac5.1 is required for the Lua 5.1 syntax gate" >&2
        return 127
    fi
    local rc=0
    while IFS= read -r -d '' f; do
        luac5.1 -p "$f" || rc=1
    done < <(find . -name '*.lua' -not -path './.git/*' -print0)
    return $rc
}

# Anything written to _G that is not on this list is an accidental global leak.
ALLOWED_GLOBALS="SLASH_MAXCAMDIST1"

global_leaks() {
    if ! command -v luac5.1 >/dev/null 2>&1; then
        echo "luac5.1 is required for the Lua 5.1 global-leak audit" >&2
        return 127
    fi
    local rc=0
    while IFS= read -r -d '' f; do
        local leaked
        # The operand column is "A B" (two numbers separated by a space), so a
        # \S+ between SETGLOBAL and the ';' comment never matched and this audit
        # silently passed on everything. Verified against real luac5.1 output:
        #   SETGLOBAL<TAB>24 -85<TAB>; BadGlobal
        leaked=$(luac5.1 -l -l "$f" 2>/dev/null \
            | grep -oP 'SETGLOBAL.*?;\s+\K\S+' \
            | sort -u \
            | grep -vxF "$ALLOWED_GLOBALS" || true)
        if [[ -n "$leaked" ]]; then
            echo "global leak in $f:"
            echo "$leaked" | sed 's/^/  /'
            rc=1
        fi
    done < <(find . -name '*.lua' -not -path './libs/*' -not -path './tests/*' -print0)
    return $rc
}


lua51_probe() {
    if ! command -v lua5.1 >/dev/null 2>&1; then
        echo "lua5.1 is required for runtime regression probes" >&2
        return 127
    fi
    lua5.1 "$@"
}

xml_wellformed() {
    python3 - <<'PY'
import glob, sys, xml.etree.ElementTree as ET
rc = 0
for f in glob.glob('*.xml') + glob.glob('*/_manifest.xml'):
    try:
        ET.parse(f)
    except ET.ParseError as exc:
        print(f"malformed XML: {f}: {exc}")
        rc = 1
sys.exit(rc)
PY
}

stage "Lua 5.1 syntax"            lua_syntax
stage "Global leak audit"         global_leaks
stage "XML well-formedness"       xml_wellformed
stage "TOC files current"         python3 tools/generate_tocs.py --check
stage "Manifest references"       python3 tools/verify_manifest.py --allow-missing-externals
stage "Probe: late Ace3"          lua51_probe tests/probe_lateace3.lua
stage "Probe: gamepad/shoulder"   lua51_probe tests/probe_gamepad.lua
stage "Probe: LibCamera ranges"    lua51_probe tests/probe_libcamera.lua
stage "Probe: flavor matrix"       lua51_probe tests/probe_flavors.lua

echo ""
if [[ $failures -eq 0 ]]; then
    echo "ALL CHECKS PASSED"
else
    echo "${failures} STAGE(S) FAILED"
fi
exit $failures
