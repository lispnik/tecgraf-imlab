#!/bin/bash
# Runs ImLab's tests.
#
# ImLab is a graphical application, so these run the real program with a probe injected into it
# (test/imlab_probe.m) and drive it through the callbacks its menus use. Each scenario is a
# separate run, because each one ends by exiting the program.
#
#   usage: run_tests.sh <path-to-imlab> [scenario ...]     (default: every scenario)
#
# The windows are made transparent and the application is kept out of the Dock while the tests
# run, so a test run does not take over the desktop. That is what PROBE_BACKGROUND does, and it
# comes from IUP's own test probe -- which is also what makes a window appear at all under a
# non-interactive session.
set -u

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
IMLAB=${1:-}
shift 2>/dev/null || true

if [ -z "$IMLAB" ] || [ ! -x "$IMLAB" ]; then
  echo "usage: run_tests.sh <path-to-imlab> [scenario ...]" >&2
  exit 2
fi

# Absolute: each scenario runs from a temporary directory, so a relative path would not resolve.
IMLAB=$(cd "$(dirname "$IMLAB")" && pwd)/$(basename "$IMLAB")

# IUP, for its headers and its probe. The same lookup the build uses.
IUP_ROOT=${IUP_ROOT:-${IUP:-$HERE/../../tecgraf-iup}}
if [ ! -e "$IUP_ROOT/include/iup.h" ]; then
  echo "IUP source tree not found; set IUP_ROOT" >&2
  exit 2
fi

IUP_LIB_DIR=${IUP_LIB_DIR:-$IUP_ROOT/BUILD-xcode/Release}
IUP_PROBE=$IUP_ROOT/cocoa-tests/probe.dylib

if [ ! -e "$IUP_PROBE" ]; then
  clang -dynamiclib -o "$IUP_PROBE" "$IUP_ROOT/cocoa-tests/probe.m" -framework Cocoa || exit 1
fi

BIN=$HERE/build
mkdir -p "$BIN"
PROBE=$BIN/imlab_probe.dylib

if [ ! -e "$PROBE" ] || [ "$HERE/imlab_probe.m" -nt "$PROBE" ]; then
  clang -dynamiclib -o "$PROBE" "$HERE/imlab_probe.m" \
        -I"$IUP_ROOT/include" -I"$IUP_ROOT/src" \
        -framework Cocoa -F"$IUP_LIB_DIR" -framework iup \
        -Wl,-rpath,"$IUP_LIB_DIR" -undefined dynamic_lookup || exit 1
fi

SCENARIOS=("$@")
if [ ${#SCENARIOS[@]} -eq 0 ]; then
  SCENARIOS=(startup saveas save-edited)
fi

WORK=$(mktemp -d /tmp/imlab-test.XXXXXX)
trap 'rm -rf "$WORK"' EXIT
cp "$HERE/../etc/ImLab.png" "$WORK/input.png"

status=0
for scenario in "${SCENARIOS[@]}"; do
  echo "=== $scenario"

  # A fresh output name per scenario, so a stale file cannot make a test pass.
  output=$WORK/$scenario-output.png
  rm -f "$output"

  # Save As starts from the name of the file that is open, so hand it one named like the output.
  input=$WORK/input.png
  if [ "$scenario" = saveas ] || [ "$scenario" = save-edited ]; then
    input=$output
    cp "$WORK/input.png" "$input"
    # ...and make it older than the run, so "was it written" cannot be answered by the copy.
    touch -t 202001010000 "$input"
  fi

  out=$(cd "$WORK" && timeout 90 env \
        IMLAB_TEST="$scenario" IMLAB_TEST_OUTPUT="$output" \
        PROBE_BACKGROUND=1 PROBE_SECONDS=60 PROBE_LOG=/dev/null \
        DYLD_INSERT_LIBRARIES="$IUP_PROBE:$PROBE" \
        "$IMLAB" "$input" 2>/dev/null)
  rc=$?

  echo "$out" | grep -E '^(ok|FAIL)|failure\(s\)'
  if [ "$rc" != "0" ]; then
    echo "  scenario exited $rc"
    status=1
  fi
done

if [ "$status" = "0" ]; then
  echo "no failures"
else
  echo "FAILURES (see above)"
fi
exit $status
