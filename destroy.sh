#!/bin/bash
set -euo pipefail

source config.sh
source ./scripts/util.sh

CERT_DIR="./.cert"

AWS_ACCOUNT_ID=""


destroy_alb() {
    echo "Uninstalling ingress..."
    if helm status ingress-release &> /dev/null; then
        helm uninstall ingress-release
    else
        echo "Ingress release 'ingress-release' already uninstalled or doesn't exist."
    fi

    echo "Uninstalling AWS Load Balancer Controller..."
    if helm status aws-load-balancer-controller -n kube-system &> /dev/null; then
        helm uninstall aws-load-balancer-controller -n kube-system
    else
        echo "Load Balancer Controller release 'aws-load-balancer-controller' already uninstalled \
            or doesn't exist."
    fi

    echo "Uninstalling AWS Load Balancer Controller Service Account..."
    if helm status sa-release &> /dev/null; then
        helm uninstall sa-release
    else
        echo "Service account release 'sa-release' already uninstalled or doesn't exist."
    fi

    local retries=120
    local sleep_interval=5

    echo "Waiting for ingress resource to be destroyed..."

    for ((i=1; i<=retries; i++)); do
        local ingress_status=$(kubectl get ingress live-chat-app-ingress --ignore-not-found)

        if [[ -z "$ingress_status" ]]; then
            echo "Ingress resource 'live-chat-app-ingress' destroyed"
            return 0
        fi

        echo "Ingress resource still exists, retrying in $sleep_interval seconds... ($i/$retries)"
        sleep $sleep_interval
    done

    echo "Failed to detect ingress resource destruction after $retries attempts. Exiting."
    exit 1
}


uninstall_app() {
    echo "Uninstalling application..."
    if helm status app-release &> /dev/null; then
        helm uninstall app-release
        
        echo "Application uninstalled"
    else
        echo "App release 'app-release' already uninstalled or doesn't exist."
    fi
}


destroy_terraform() {
    echo "Destroying resources with Terraform (this may take a while)..."

    pushd terraform > /dev/null

    terraform destroy \
        -var "project=$PROJECT" \
        -var "cluster_name=$CLUSTER_NAME" \
        -var "username=$USERNAME" \
        -var "region=$REGION" \
        -var "eks_instance_type=$EKS_INSTANCE_TYPE" \
        -var "eks_desired_nodes=$EKS_DESIRED_NODES" \
        -var "eks_min_nodes=$EKS_MIN_NODES" \
        -var "eks_max_nodes=$EKS_MAX_NODES" \
        -var "allowed_cidr=0.0.0.0/0" \
        --auto-approve

    echo "Resources destroyed with Terraform"

    popd > /dev/null
}


delete_kube_context() {
    echo "Deleting kubectl context for cluster $CLUSTER_NAME..."
    kubectl config delete-context "arn:aws:eks:$REGION:$AWS_ACCOUNT_ID:cluster/$CLUSTER_NAME" || true
}


delete_cert_dir() {
    if [ -d "$CERT_DIR" ]; then
        rm -rf "$CERT_DIR"
        echo "Local SSL certification directory deleted"
    fi
}


check_aws_env
check_commands
check_config_variables
get_aws_account_id
destroy_alb
uninstall_app
destroy_terraform
delete_kube_context
delete_cert_dir

echo "All resources cleaned up!"
