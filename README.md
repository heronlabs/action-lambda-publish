# Publish Lambda Action

[![CI](https://github.com/heronlabs/action-lambda-publish/actions/workflows/ci.yml/badge.svg)](https://github.com/heronlabs/action-lambda-publish/actions/workflows/ci.yml)

A GitHub Action to deploy container images to AWS Lambda functions using OIDC authentication.

## Overview

This action updates an existing AWS Lambda function's code by pointing it to a new container image. It handles AWS credential configuration via OIDC (OpenID Connect) role assumption, eliminating the need to store long-lived AWS credentials as secrets.

Use this action when you need to deploy containerized Lambda functions as part of your CI/CD pipeline.

## Requirements

### Supported Runners

- `ubuntu-latest` (recommended)
- Any Linux-based GitHub-hosted or self-hosted runner with `bash` and AWS CLI installed

### AWS Prerequisites

1. **OIDC Identity Provider**: Configure GitHub as an OIDC provider in your AWS account. See [AWS documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html).

2. **IAM Role**: Create an IAM role with a trust policy that allows GitHub Actions to assume it. The role must have the following permissions:

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

3. **Lambda Function**: The target Lambda function must already exist and be configured to use container images.

### GitHub Permissions

The workflow must have `id-token: write` permission to request the OIDC token:

```yaml
permissions:
  id-token: write
  contents: read
```

## Inputs

| Name | Description | Required | Default |
|------|-------------|----------|---------|
| `AWS_ROLE_TO_ASSUME` | ARN of the IAM role to assume via OIDC | Yes | - |
| `AWS_REGION` | AWS region where the Lambda function is deployed | Yes | - |
| `AWS_ROLE_DURATION_SECONDS` | Duration in seconds for the assumed role session | Yes | - |
| `LAMBDA_IMAGE` | Full URI of the container image (e.g., `123456789.dkr.ecr.us-east-1.amazonaws.com/my-app:latest`) | Yes | - |
| `LAMBDA_NAME` | Name of the Lambda function to update | Yes | - |

## Outputs

This action does not produce outputs.

## Usage

### Minimal Example

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
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to Lambda
        uses: heronlabs/action-lambda-publish@v1
        with:
          AWS_ROLE_TO_ASSUME: arn:aws:iam::123456789012:role/github-actions-lambda-deploy
          AWS_REGION: us-east-1
          AWS_ROLE_DURATION_SECONDS: 900
          LAMBDA_IMAGE: 123456789012.dkr.ecr.us-east-1.amazonaws.com/my-app:${{ github.sha }}
          LAMBDA_NAME: my-lambda-function
```

### Advanced Example: Build and Deploy

```yaml
name: Build and Deploy Lambda

on:
  push:
    branches: [main]

permissions:
  id-token: write
  contents: read

env:
  AWS_REGION: us-east-1
  ECR_REPOSITORY: my-app
  LAMBDA_NAME: my-lambda-function

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      # Configure AWS credentials for ECR push
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v5
        with:
          role-to-assume: arn:aws:iam::123456789012:role/github-actions-ecr-push
          aws-region: ${{ env.AWS_REGION }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build and push image
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG

      # Deploy to Lambda using this action
      - name: Deploy to Lambda
        uses: heronlabs/action-lambda-publish@v1
        with:
          AWS_ROLE_TO_ASSUME: arn:aws:iam::123456789012:role/github-actions-lambda-deploy
          AWS_REGION: ${{ env.AWS_REGION }}
          AWS_ROLE_DURATION_SECONDS: 900
          LAMBDA_IMAGE: ${{ steps.login-ecr.outputs.registry }}/${{ env.ECR_REPOSITORY }}:${{ github.sha }}
          LAMBDA_NAME: ${{ env.LAMBDA_NAME }}
```

### Multi-Environment Deployment

```yaml
name: Deploy to Multiple Environments

on:
  push:
    branches:
      - main
      - develop

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        include:
          - environment: staging
            lambda_name: my-app-staging
            role_arn: arn:aws:iam::111111111111:role/github-actions-lambda-deploy
          - environment: production
            lambda_name: my-app-prod
            role_arn: arn:aws:iam::222222222222:role/github-actions-lambda-deploy
    steps:
      - name: Deploy to ${{ matrix.environment }}
        uses: heronlabs/action-lambda-publish@v1
        with:
          AWS_ROLE_TO_ASSUME: ${{ matrix.role_arn }}
          AWS_REGION: us-east-1
          AWS_ROLE_DURATION_SECONDS: 900
          LAMBDA_IMAGE: 123456789012.dkr.ecr.us-east-1.amazonaws.com/my-app:${{ github.sha }}
          LAMBDA_NAME: ${{ matrix.lambda_name }}
```

## Important Notes

- **Container images only**: This action only works with Lambda functions configured to use container images, not ZIP deployments.
- **No function creation**: The Lambda function must already exist. This action only updates the function code.
- **Async update**: The `update-function-code` command is asynchronous. The function may still be updating after the action completes.
- **Role session duration**: Set `AWS_ROLE_DURATION_SECONDS` to at least 900 (15 minutes). Shorter durations may cause failures for large images.

## Common Errors

### `Error: Not authorized to perform: sts:AssumeRoleWithWebIdentity`

**Cause**: The IAM role trust policy does not allow GitHub Actions to assume the role.

**Solution**: Verify the trust policy includes the correct GitHub OIDC provider and conditions:

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
          "token.actions.githubusercontent.com:sub": "repo:your-org/your-repo:*"
        }
      }
    }
  ]
}
```

### `Error: Function not found`

**Cause**: The Lambda function name is incorrect or does not exist in the specified region.

**Solution**: Verify the function name and region. Ensure the function exists before running this action.

### `Error: AccessDeniedException when calling UpdateFunctionCode`

**Cause**: The IAM role lacks `lambda:UpdateFunctionCode` permission.

**Solution**: Add the required permission to the IAM role policy.

### `Error: The image manifest or layer media type is not supported`

**Cause**: The container image is not compatible with Lambda.

**Solution**: Ensure the image is built for `linux/amd64` architecture and uses a Lambda-compatible base image.

## License

MIT
