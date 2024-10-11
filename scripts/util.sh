#!/bin/bash

check_commands() {
    for cmd in terraform aws helm kubectl docker curl openssl; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "$cmd is missing! Please install before use. Exiting."
            exit 1
        fi
    done
}


check_config_variables() {
    local required_vars=(
        "PROJECT"
        "CLUSTER_NAME"
        "USERNAME"
        "REGION"
        "BACKEND_MODULE_PORT"
        "UI_MODULE_PORT"
        "REDIS_PORT"
        "EKS_INSTANCE_TYPE"
        "EKS_DESIRED_NODES"
        "EKS_MIN_NODES"
        "EKS_MAX_NODES"
        "NUM_REDIS_REPLICAS"
        "BACKEND_MIN_REPLICAS"
        "BACKEND_MAX_REPLICAS"
        "BACKEND_TARGET_CPU_UTILIZATION_PCT"
        "UI_MIN_REPLICAS"
        "UI_MAX_REPLICAS"
        "UI_TARGET_CPU_UTILIZATION_PCT"
        "BACKEND_MEMORY_REQUEST"
        "BACKEND_MEMORY_LIMIT"
        "BACKEND_CPU_REQUEST"
        "BACKEND_CPU_LIMIT"
        "UI_MEMORY_REQUEST"
        "UI_MEMORY_LIMIT"
        "UI_CPU_REQUEST"
        "UI_CPU_LIMIT"
    )

    local all_set=true

    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            echo "Error: $var is not set."
            all_set=false
        fi
    done

    if [ "$all_set" = true ]; then
        echo "All required configuration variables are set"
        return 0
    else
        echo "Some configuration variables are missing! Please set them in config.sh \
            before proceeding. Exiting."
        return 1
    fi
}


check_aws_env() {
    if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
        echo "AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY must be set as environment \
            variables! Exiting."
        exit 1
    fi
}

get_aws_account_id() {
    echo "Retrieving AWS Account ID..."

    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

    if [[ -z "$AWS_ACCOUNT_ID" ]]; then
        echo "Failed to retrieve AWS Account ID! Exiting."
        exit 1
    fi

    echo "AWS Account ID retrieved: $AWS_ACCOUNT_ID"
}