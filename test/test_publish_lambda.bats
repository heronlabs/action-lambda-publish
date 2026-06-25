#!/usr/bin/env bats
# bats tests for core/publish-lambda.sh
#
# Uses the `aws` stub to capture CLI invocations and asserts on exit codes
# and logged arguments. No network, no real AWS.

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../core/publish-lambda.sh"
  STUB_DIR="$BATS_TEST_DIRNAME"   # contains the `aws` stub

  # Keep runs deterministic regardless of the caller's shell.
  unset LAMBDA_NAME LAMBDA_IMAGE
}

# Run the action script with the `aws` stub on PATH and an isolated log file.
# Usage: run_action [env assignments...]
# Sets RUN_OUT, RUN_RC, RUN_AWSLOG for the caller.
# shellcheck disable=SC2034  # RUN_OUT is used by callers in assertions
run_action() {
  RUN_AWSLOG="$(mktemp)"
  : >"$RUN_AWSLOG"
  set +e
  RUN_OUT="$(
    env PATH="$STUB_DIR:$PATH" \
        AWS_LOG="$RUN_AWSLOG" \
        "$@" \
        bash "$SCRIPT" 2>&1
  )"
  RUN_RC=$?
  set -e
}

# ---------------------------------------------------------------- tests

@test "happy path: updates lambda function code" {
  run_action LAMBDA_NAME=my-fn LAMBDA_IMAGE=123.dkr.ecr.amazonaws.com/img:tag

  [ "$RUN_RC" -eq 0 ]
  grep -q 'lambda update-function-code' "$RUN_AWSLOG"
  grep -q -- '--function-name my-fn' "$RUN_AWSLOG"
  grep -q -- '--image-uri 123.dkr.ecr.amazonaws.com/img:tag' "$RUN_AWSLOG"

  rm -f "$RUN_AWSLOG"
}

@test "missing name: hard error, aws not invoked" {
  run_action LAMBDA_IMAGE=123.dkr.ecr.amazonaws.com/img:tag

  [ "$RUN_RC" -ne 0 ]
  [ ! -s "$RUN_AWSLOG" ]

  rm -f "$RUN_AWSLOG"
}

@test "missing image: hard error, aws not invoked" {
  run_action LAMBDA_NAME=my-fn

  [ "$RUN_RC" -ne 0 ]
  [ ! -s "$RUN_AWSLOG" ]

  rm -f "$RUN_AWSLOG"
}
