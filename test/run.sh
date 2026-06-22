#!/usr/bin/env bash
# Offline test harness for core/publish-lambda.sh.
#
# Points an `aws` stub at PATH, runs the action script with LAMBDA_NAME/LAMBDA_IMAGE
# in the environment, and asserts on exit code and the logged aws argv.
# No network, no real AWS.
#
# shellcheck disable=SC2015  # `cond && ok || bad` is intentional; ok() always returns 0
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../core/publish-lambda.sh"
STUB_DIR="$HERE"   # contains the `aws` stub

# Keep runs deterministic regardless of the caller's shell.
unset LAMBDA_NAME LAMBDA_IMAGE

pass=0
fail=0
note() { printf '  %s\n' "$*"; }
ok()   { pass=$((pass + 1)); printf 'ok   - %s\n' "$1"; }
bad()  { fail=$((fail + 1)); printf 'FAIL - %s\n' "$1"; [ -n "${2:-}" ] && note "$2"; }

# Run the action script with the `aws` stub on PATH and an isolated log file.
# Usage: run_action [env assignments...]
# Exports RUN_OUT/RUN_RC/RUN_AWSLOG for the caller.
run_action() {
  RUN_AWSLOG="$(mktemp)"
  : >"$RUN_AWSLOG"
  RUN_OUT="$(
    env PATH="$STUB_DIR:$PATH" \
        AWS_LOG="$RUN_AWSLOG" \
        "$@" \
        bash "$SCRIPT" 2>&1
  )"
  RUN_RC=$?
}

# ---------------------------------------------------------------- tests

test_happy_path() {
  run_action LAMBDA_NAME=my-fn LAMBDA_IMAGE=123.dkr.ecr.amazonaws.com/img:tag

  [ "$RUN_RC" -eq 0 ] && ok "happy: exit 0 (green)" || bad "happy: exit 0 (green)" "rc=$RUN_RC out=$RUN_OUT"
  grep -q 'lambda update-function-code' "$RUN_AWSLOG" && ok "happy: update-function-code invoked" || bad "happy: update-function-code invoked" "$(cat "$RUN_AWSLOG")"
  grep -q -- '--function-name my-fn' "$RUN_AWSLOG" && ok "happy: --function-name my-fn" || bad "happy: --function-name my-fn" "$(cat "$RUN_AWSLOG")"
  grep -q -- '--image-uri 123.dkr.ecr.amazonaws.com/img:tag' "$RUN_AWSLOG" && ok "happy: --image-uri passed through" || bad "happy: --image-uri passed through" "$(cat "$RUN_AWSLOG")"

  rm -f "$RUN_AWSLOG"
}

test_missing_name_hard_error() {
  run_action LAMBDA_IMAGE=123.dkr.ecr.amazonaws.com/img:tag

  [ "$RUN_RC" -ne 0 ] && ok "missing name: hard error (non-zero)" || bad "missing name: hard error (non-zero)" "rc=$RUN_RC out=$RUN_OUT"
  [ ! -s "$RUN_AWSLOG" ] && ok "missing name: aws NOT invoked" || bad "missing name: aws NOT invoked" "$(cat "$RUN_AWSLOG")"

  rm -f "$RUN_AWSLOG"
}

test_missing_image_hard_error() {
  run_action LAMBDA_NAME=my-fn

  [ "$RUN_RC" -ne 0 ] && ok "missing image: hard error (non-zero)" || bad "missing image: hard error (non-zero)" "rc=$RUN_RC out=$RUN_OUT"
  [ ! -s "$RUN_AWSLOG" ] && ok "missing image: aws NOT invoked" || bad "missing image: aws NOT invoked" "$(cat "$RUN_AWSLOG")"

  rm -f "$RUN_AWSLOG"
}

# ---------------------------------------------------------------- run

test_happy_path
test_missing_name_hard_error
test_missing_image_hard_error

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
