#!/bin/bash

image_tag=$1
repository_name=$2
dockerfile_path=$3
context_dir=$4
region=$5

echo "Pushing image '${image_tag}' to ECR repository '${repository_name}'..."

docker build \
    --no-cache \
    -f "$dockerfile_path" \
    --platform linux/amd64 \
    -t "$image_tag" \
    "$context_dir" \
    || { echo "Docker build failed for $image_tag. Aborting."; exit 1; }

account_id=$(aws sts get-caller-identity | jq -r ".Account")
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
