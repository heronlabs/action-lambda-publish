#!/bin/bash
set -euo pipefail

aws lambda update-function-code \
--function-name "${LAMBDA_NAME}" \
--image-uri "${LAMBDA_IMAGE}"