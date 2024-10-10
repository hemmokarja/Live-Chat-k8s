#!/bin/bash

IMAGE_TAG=$1
REPOSITORY_NAME=$2
DOCKERFILE_PATH=$3
CONTEXT_DIR=$4
REGION=$5

echo "Building and pushing image '${IMAGE_TAG}' to ECR repository (this might take a while)..."

docker build \
    --no-cache \
    -f "$DOCKERFILE_PATH" \
    --platform linux/amd64 \
    -t "$IMAGE_TAG" \
    "$CONTEXT_DIR"

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
if [[ -z "$AWS_ACCOUNT_ID" ]]; then
    echo "Failed to retrieve AWS account ID. Exiting."
    exit 1
fi

aws ecr get-login-password --region "$REGION" | \
    docker login \
    --username AWS \
    --password-stdin \
    "$AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

docker tag \
    "$IMAGE_TAG:latest" \
    "$AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPOSITORY_NAME:latest"

docker push "$AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPOSITORY_NAME:latest"

echo "Built and pushed image '${IMAGE_TAG}' to ECR repository"
