#!/bin/bash

source config.sh
source ./scripts/utils.sh

APP_DIR="../src/livechatapp"
BACKEND_DIR="$APP_DIR/backend"
UI_DIR="$APP_DIR/src/ui"
PUSH_IMAGES_SCRIPT="./scripts/push_image.sh"
HELM_DIR="./helm"

PROJECT_LOWER=$(echo "$PROJECT" | tr "[:upper:]" "[:lower:]")
BACKEND_REPOSITORY_NAME="$PROJECT_LOWER/backend_module"
UI_REPOSITORY_NAME="$PROJECT_LOWER/ui_module"

PUBLIC_IP=""
VPC_ID=""
AWS_LB_CONTROLLER_ROLE_ARN=""
ACM_CERTIFICATE_ARN=""


get_public_ip() {
  PUBLIC_IP=$(curl -s -4 http://ifconfig.co)
  
  if [[ $? -eq 0 ]]; then
    echo "Public IP retrieved successfully."
  else
    echo "Failed to retrieve public IP. Exiting."
    return 1
  fi
}


apply_terraform() {
  terraform apply \
    -var "project=$PROJECT" \
    -var "cluster_name=$CLUSTER_NAME" \
    -var "username=$USERNAME" \
    -var "region=$REGION" \
    -var "eks_instance_type=$EKS_INSTANCE_TYPE" \
    -var "eks_desired_nodes=$EKS_DESIRED_NODES" \
    -var "eks_min_nodes=$EKS_MIN_NODES" \
    -var "eks_max_nodes=$EKS_MAX_NODES" \
    -var "allowed_cidr=$PUBLIC_IP/32" \
    -var "num_backend_replicas=$NUM_BACKEND_REPLICAS" \
    -var "num_ui_replicas=$NUM_UI_REPLICAS" \
    --auto-approve

    if [ $? -ne 0 ]; then
        echo "Terraform apply failed. Exiting."
        exit 1
    fi

    # obtain output
    VPC_ID=$(terraform output -raw vpc_id)
    AWS_LB_CONTROLLER_ROLE_ARN=$(terraform output -raw aws_lb_controller_role_arn)
    ACM_CERTIFICATE_ARN=$(terraform output -raw acm_certificate_arn)

    if [[ -z "$VPC_ID" || -z "$AWS_LB_CONTROLLER_ROLE_ARN" || -z "$ACM_CERTIFICATE_ARN" ]]; then
        echo "Failed to retrieve some Terraform outputs."
        return 1
    fi

    echo "Terraform outputs captured successfully:"
    echo "VPC ID: $VPC_ID"
    echo "AWS Load Balancer Controller Role ARN: $AWS_LB_CONTROLLER_ROLE_ARN"
    echo "ACM Certificate ARN: $ACM_CERTIFICATE_ARN"
}


update_kubectl_context() {
    echo "Updating kubectl config for cluster $CLUSTER_NAME in region $REGION..."
    aws eks --region $REGION update-kubeconfig --name $CLUSTER_NAME
}


install_load_balancer_controller() {
    echo "Installing AWS Load Balancer Controller..."

    helm repo add eks https://aws.github.io/eks-charts \
        || { echo "Failed to add EKS Helm repository. Exiting."; exit 1; }
    helm repo update \
        || { echo "Failed to update Helm repositories. Exiting."; exit 1; }

    helm upgrade -i aws-load-balancer-controller eks/aws-load-balancer-controller \
        -n kube-system \
        --set "clusterName=$CLUSTER_NAME" \
        --set serviceAccount.create=false \
        --set serviceAccount.name=aws-load-balancer-controller \
        --set "region=$REGION" \
        --set vpcId=$VPC_ID \
        --set "image.repository=602401143452.dkr.ecr.$REGION.amazonaws.com/amazon/aws-load-balancer-controller" \
        --set enableCertManager=false \
        || { echo "Failed to install AWS Load Balancer Controller. Exiting."; exit 1; }
}


provision_alb() {
    echo "Installing AWS Load Balancer Controller Service Account..."
    helm install sa-release "$HELM_DIR/sa-chart" \
        --set "awsLoadBalancerControllerRoleArn=$AWS_LB_CONTROLLER_ROLE_ARN" \
        || { echo "Failed to install Service Account. Exiting."; exit 1; }

    install_load_balancer_controller

    echo "Provisioning AWS ALB..."
    helm install ingress-release "$HELM_DIR/ingress-chart" \
        --set "acmCertificateArn=$ACM_CERTIFICATE_ARN" \
        --set "uiServicePort=$UI_MODULE_PORT" \
        --set "backendServicePort=$BACKEND_MODULE_PORT" \
        || { echo "Failed to provision ALB. Exiting."; exit 1; }
}


check_commands
check_aws_env
get_public_ip
apply_terraform
update_kubectl_context

bash "$PUSH_IMAGES_SCRIPT" \
    "backend_module" \
    "$BACKEND_REPOSITORY_NAME" \
    "$BACKEND_DIR/Dockerfile" \
    "$BACKEND_DIR" \
    "$REGION"

bash "$PUSH_IMAGES_SCRIPT" \
    "ui_module" \
    "$UI_REPOSITORY_NAME" \
    "$UI_DIR/Dockerfile" \
    "$UI_DIR" \
    "$REGION"

provision_alb