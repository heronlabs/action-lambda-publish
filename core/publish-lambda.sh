#!/bin/bash

aws lambda update-function-code \
  --function-name ${LAMBDA_NAME} \
  --image-uri ${LAMBDA_IMAGE}