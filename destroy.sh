#!/bin/bash
set -euo pipefail

source config.sh
source ./scripts/util.sh

CERT_DIR="./.cert"

AWS_ACCOUNT_ID=""


uninstall_ingress() {
    local retries=60
    local sleep_interval=5
    
    echo "Uninstalling ingress..."
    if helm status ingress-release &> /dev/null; then
        helm uninstall ingress-release
    else
        echo "Ingress release 'ingress-release' already uninstalled or doesn't exist."
    fi

    echo "Waiting for ingress resource to be destroyed..."
    # it's necessary to remove the ingress and destroy the ALB before proceeding to 
    # remove the controller, otherwise the 
    # for more see e.g.: https://github.com/hashicorp/terraform-provider-helm/issues/474
    for ((i=1; i<=retries; i++)); do
        if ! kubectl get ingress live-chat-ingress &> /dev/null; then
            echo "Ingress resource 'live-chat-ingress' destroyed"
            sleep 10
            return 0
        fi
        
        echo "Ingress resource still exists, retrying in $sleep_interval seconds... ($i/$retries)"
        sleep $sleep_interval
    done

    echo "Failed to detect ingress resource destruction after $retries attempts. Exiting."
    exit 1
}


uninstall_load_balancer_controller() {
    echo "Uninstalling AWS Load Balancer Controller..."
    if helm status aws-load-balancer-controller -n kube-system &> /dev/null; then
        helm uninstall aws-load-balancer-controller -n kube-system
        sleep 10
    else
        echo "Load Balancer Controller release 'aws-load-balancer-controller' already uninstalled \
            or doesn't exist."
    fi

    echo "Uninstalling AWS Load Balancer Controller Service Account..."
    if helm status service-account-release &> /dev/null; then
        helm uninstall service-account-release
        sleep 10
    else
        echo "Service account release 'service-account-release' already uninstalled or doesn't exist."
    fi
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


uninstall_metrics_server() {
    echo "Deleting Metrics Server components..."
    kubectl delete -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

    echo "Waiting for API service to be deleted..."
    until ! kubectl get apiservice v1beta1.metrics.k8s.io &> /dev/null; do
        echo "API service still exists, waiting..."
        sleep 5
    done

    echo "Waiting for Metrics Server deployment to be deleted..."
    until ! kubectl get deployment metrics-server -n kube-system &> /dev/null; do
        echo "Deployment still exists, waiting..."
        sleep 5
    done
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
uninstall_ingress
uninstall_load_balancer_controller
uninstall_app
uninstall_metrics_server
destroy_terraform
delete_kube_context
delete_cert_dir

echo "All resources cleaned up!"
