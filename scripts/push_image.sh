#!/bin/bash
docker build \
    --no-cache \
    -f "$DOCKERFILE_PATH" \
    --platform linux/amd64 \
    -t "$IMAGE_TAG" \
    "$CONTEXT_DIR"
ACCOUNT_ID=$(aws sts get-caller-identity | jq -r ".Account")
aws ecr get-login-password --region "$REGION" | \
    docker login \
    --username AWS \
    --password-stdin \
    "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"
docker tag \
    "$IMAGE_TAG:latest" \
    "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPOSITORY_NAME:latest"
docker push "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPOSITORY_NAME:latest"
