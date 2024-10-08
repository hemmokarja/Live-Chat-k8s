#!/bin/bash

#!/bin/bash

REGION=eu-north-1
BACKEND_REPOSITORY_NAME=livechatapp/backend_module
UI_REPOSITORY_NAME=livechatapp/ui_module
BACKEND_DIR="../src/backend"
UI_DIR="../src/ui"


build_and_push_image() {
    local image_tag=$1
    local repository_name=$2
    local dockerfile_path=$3
    local context_dir=$4
    local region=$REGION

    docker build \
        --no-cache \
        -f "$dockerfile_path" \
        --platform linux/amd64 \
        -t "$image_tag" \
        "$context_dir" \
        || { echo "Docker build failed for $image_tag. Aborting."; exit 1; }

    local account_id=$(aws sts get-caller-identity | jq -r ".Account")
    if [[ -z "$account_id" ]]; then
        echo "Failed to retrieve AWS account ID. Aborting."
        exit 1
    fi

    aws ecr get-login-password --region "$region" | \
        docker login \
        --username AWS \
        --password-stdin \
        "$account_id.dkr.ecr.$region.amazonaws.com" \
        || { echo "ECR login failed for $image_tag. Aborting."; exit 1; }

    docker tag \
        "$image_tag:latest" \
        "$account_id.dkr.ecr.$region.amazonaws.com/$repository_name:latest" \
        || { echo "Docker tag failed for $image_tag. Aborting."; exit 1; }

    docker push "$account_id.dkr.ecr.$region.amazonaws.com/$repository_name:latest" \
        || { echo "Docker push failed for $image_tag. Aborting."; exit 1; }

    echo "Image $image_tag pushed successfully!"
}


echo "Pushing Backend Module image..."
build_and_push_image \
    "backend_module" \
    "$BACKEND_REPOSITORY_NAME" \
    "$BACKEND_DIR/Dockerfile" \
    "$BACKEND_DIR"


echo "Pushing UI Module image..."
build_and_push_image \
    "ui_module" \
    "$UI_REPOSITORY_NAME" \
    "$UI_DIR/Dockerfile" \
    "$UI_DIR"

echo "All images pushed successfully!"
