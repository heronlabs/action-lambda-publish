# 🥁 action-lambda-publish — Update an existing container-image AWS Lambda function.

[![CI](https://github.com/heronlabs/action-lambda-publish/actions/workflows/continuous-integration.yml/badge.svg)](https://github.com/heronlabs/action-lambda-publish/actions/workflows/continuous-integration.yml)

> Update an existing container-image AWS Lambda function to a new image via OIDC.

Assumes an IAM role with OIDC (no long-lived AWS secrets) and points the target Lambda at a new container image. The function must already exist; this action updates its code only.

## Contents

- [Usage](#usage)
- [Inputs](#inputs)
- [Outputs](#outputs)
- [Permissions](#permissions)
- [How it works](#how-it-works)
- [Notes](#notes)
- [License](#license)

## Usage

```yaml
name: Deploy Lambda

on:
  push:
    branches: [main]

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-24.04
    steps:
      - name: Deploy to Lambda
        uses: heronlabs/action-lambda-publish@v3
        with:
          AWS_ROLE_TO_ASSUME: arn:aws:iam::123456789012:role/github-actions-lambda-deploy
          AWS_REGION: us-east-1
          AWS_ROLE_DURATION_SECONDS: 900
          LAMBDA_IMAGE: 123456789012.dkr.ecr.us-east-1.amazonaws.com/my-app:${{ github.sha }}
          LAMBDA_NAME: my-lambda-function
```

## Inputs

| Name | Description | Required | Default |
|------|-------------|----------|---------|
| `AWS_ROLE_TO_ASSUME` | ARN of the IAM role to assume via OIDC. | Yes | — |
| `AWS_REGION` | AWS region of the Lambda function. | Yes | — |
| `AWS_ROLE_DURATION_SECONDS` | Assumed-role session duration, in seconds. | Yes | — |
| `LAMBDA_IMAGE` | Full container image URI to deploy. | Yes | — |
| `LAMBDA_NAME` | Name of the Lambda function to update. | Yes | — |

## Outputs

This action produces no outputs.

## Permissions

```yaml
permissions:
  id-token: write
  contents: read
```

<details>
<summary>AWS IAM policy</summary>

Trust policy on the assumed role (allow GitHub Actions OIDC):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:heronlabs/your-repo:*"
        }
      }
    }
  ]
}
```

Least-privilege permission policy on the assumed role:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "lambda:UpdateFunctionCode",
      "Resource": "arn:aws:lambda:<region>:<account-id>:function:<function-name>"
    }
  ]
}
```

</details>

## How it works

This composite action assumes an IAM role via OIDC (no static credentials) and runs `aws lambda update-function-code` with the supplied container image URI against the target function. The single shell script at `core/publish-lambda.sh` performs the update:

1. **Assume role** — `aws-actions/configure-aws-credentials` handles the OIDC exchange with the given `AWS_ROLE_TO_ASSUME`.
2. **Update function code** — `aws lambda update-function-code --function-name <LAMBDA_NAME> --image-uri <LAMBDA_IMAGE>` points the function at the new container image.

## Notes

- Container-image Lambdas only — not ZIP deployments.
- The function must already exist; this updates its code and never creates it.
- `update-function-code` is asynchronous; the function may still be updating when the action returns.
- Set `AWS_ROLE_DURATION_SECONDS` to at least `900`.

## License

MIT
