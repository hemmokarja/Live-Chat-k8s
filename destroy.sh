#!/bin/bash
set -euo pipefail

source ./scripts/load_config.sh
source ./scripts/util.sh

CERT_DIR="./.cert"

AWS_ACCOUNT_ID=""


uninstall_app() {
    echo "Uninstalling application..."
    if helm status app-release &> /dev/null; then
        helm uninstall app-release
        
        echo "Application uninstalled"
    else
        echo "Release 'app-release' already uninstalled or doesn't exist."
    fi
    sleep 5
}


uninstall_redis_messagebroker() {
    echo "Uninstalling Redis message broker..."
    if helm status redis-messagebroker-release &> /dev/null; then
        helm uninstall redis-messagebroker-release
        echo "Redis message broker uninstalled"
    else
        echo "Release 'redis-messagebroker-release' already uninstalled or doesn't exist."
    fi
    sleep 5
}


uninstall_redis_userstate_cluster() {
    echo "Uninstalling Redis user state cluster..."
    if helm status redis-userstate-release &> /dev/null; then
        helm uninstall redis-userstate-release
        echo "Redis user state cluster uninstalled"
    else
        echo "Release 'redis-userstate-release' already uninstalled or doesn't exist."
    fi
    sleep 5
}


uninstall_ebs_csi_controller_serviceaccount () {
    echo "Uninstalling EBS CSI Controller Service Account..."
    if helm status ebs-csi-controller-serviceaccount-release &> /dev/null; then
        helm uninstall ebs-csi-controller-serviceaccount-release
        echo "EBS CSI Controller Service Account uninstalled"
    else
        echo "Release 'ebs-csi-controller-serviceaccount-release' already uninstalled or doesn't exist."
    fi
    sleep 5
}


uninstall_rabbitmq_messagebroker_cluster () {
    echo "Uninstalling RabbitMQ message broker cluster..."
    if helm status rabbitmq-messagebroker-release &> /dev/null; then
        helm uninstall rabbitmq-messagebroker-release
        echo "RabbitMQ message broker cluster uninstalled"
    else
        echo "Release 'rabbitmq-messagebroker-release' already uninstalled or doesn't exist."
    fi
    sleep 5
}


uninstall_rabbitmq_serviceaccount () {
    echo "Uninstalling RabbitMQ Service Account..."
    if helm status rabbitmq-serviceaccount-release &> /dev/null; then
        helm uninstall rabbitmq-serviceaccount-release
        echo "RabbitMQ Service Account uninstalled"
    else
        echo "Release 'rabbitmq-serviceaccount-release' already uninstalled or doesn't exist."
    fi
    sleep 5
}


uninstall_ingress() {
    local retries=60
    local sleep_interval=5

    echo "Uninstalling ingress..."
    if helm status ingress-release &> /dev/null; then
        helm uninstall ingress-release
    else
        echo "Release 'ingress-release' already uninstalled or doesn't exist."
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
        echo "Release 'aws-load-balancer-controller' already uninstalled or doesn't exist."
    fi

    echo "Uninstalling AWS Load Balancer Controller Service Account..."
    if helm status aws-lb-controller-serviceaccount-release &> /dev/null; then
        helm uninstall aws-lb-controller-serviceaccount-release
        sleep 10
    else
        echo "Release 'aws-lb-controller-serviceaccount-release' already uninstalled or doesn't exist."
    fi
}


uninstall_metrics_server() {
    echo "Deleting Metrics Server components..."
    kubectl delete -f "https://github.com/kubernetes-sigs/metrics-server/releases/download/$METRICS_SERVER_VERSION/components.yaml" --ignore-not-found

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
    sleep 5
}


destroy_terraform() {
    echo "Destroying resources with Terraform (this may take a while)..."

    pushd terraform > /dev/null

    terraform destroy \
        -var "project=$PROJECT" \
        -var "cluster_name=$CLUSTER_NAME" \
        -var "username=$USERNAME" \
        -var "region=$REGION" \
        -var "eks_kubernetes_version=$EKS_KUBERNETES_VERSION" \
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
check_configuration_variables
get_aws_account_id

uninstall_app

uninstall_redis_userstate_cluster
uninstall_ebs_csi_controller_serviceaccount

uninstall_rabbitmq_messagebroker_cluster
uninstall_rabbitmq_serviceaccount

uninstall_ingress
uninstall_load_balancer_controller

uninstall_metrics_server

destroy_terraform

delete_kube_context
delete_cert_dir

echo "All resources cleaned up!"
