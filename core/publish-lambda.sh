#!/usr/bin/env bash
set -euo pipefail

: "${LAMBDA_NAME:?LAMBDA_NAME is required}"
: "${LAMBDA_IMAGE:?LAMBDA_IMAGE is required}"

aws lambda update-function-code \
--function-name "${LAMBDA_NAME}" \
--image-uri "${LAMBDA_IMAGE}"