#!/bin/bash
set -euo pipefail

source config.sh
source ./scripts/util.sh

APP_DIR="./src/app"
BACKEND_DIR="$APP_DIR/backend"
UI_DIR="$APP_DIR/ui"
PUSH_IMAGE_SCRIPT="./scripts/push_image.sh"
HELM_DIR="./helm"
CERT_DIR="./.cert"

PROJECT_LOWER=$(echo "$PROJECT" | tr "[:upper:]" "[:lower:]")
BACKEND_REPOSITORY_NAME="$PROJECT_LOWER/backend_module"
UI_REPOSITORY_NAME="$PROJECT_LOWER/ui_module"

BASE64_SECRET_KEY=""
PUBLIC_IP=""
AWS_ACCOUNT_ID=""
VPC_ID=""
AWS_LB_CONTROLLER_ROLE_ARN=""
ACM_CERTIFICATE_ARN=""
ALB_DNS=""
NUM_REDIS_REPLICAS_TOTAL=""


compute_num_redis_replicas_total() {
    if [[ $NUM_REDIS_MASTER_REPLICAS -lt 3 ]]; then
        echo "NUM_REDIS_MASTER_REPLICAS must be at least 3. Exiting."
        exit 1
    fi  
    NUM_REDIS_REPLICAS_TOTAL=$(( $NUM_REDIS_MASTER_REPLICAS * ( $NUM_REDIS_SLAVES_PER_MASTER + 1 ) ))
}


encode_flask_secret() {
    echo "Base64-encoding Flask secret key..."
    
    if [[ -z "$FLASK_SECRET_KEY" ]]; then
        echo "FLASK_SECRET_KEY must be set as environment variable. Exiting"
        exit 1
    fi
    
    BASE64_SECRET_KEY=$(echo -n "$FLASK_SECRET_KEY" | base64)
}


get_public_ip() {
    echo "Retrieving public IP..."
    PUBLIC_IP=$(curl -s -4 http://ifconfig.co)
  
    if [[ -z "$PUBLIC_IP" ]]; then
        echo "Failed to retrieve public IP. Exiting."
        exit 1
    fi

    echo "Public IP retrieved: $PUBLIC_IP"
}


create_self_signed_ssl_cert() {
    echo "Checking if SSL certificate and key exist..."

    local cert_file="$CERT_DIR/certificate.crt"
    local key_file="$CERT_DIR/private.key"

    if [ -f "$cert_file" ] && [ -f "$key_file" ]; then
        echo "SSL certificate and key already exist. Skipping creation."
        return 0
    fi 
    
    echo "SSL certificate or key not found. Creating a new self-signed SSL certificate..."
    if [ ! -d "$CERT_DIR" ]; then
        mkdir -p "$CERT_DIR"
    fi

    openssl req -x509 -newkey rsa:2048 -days 365 -nodes -subj "/CN=placeholder.com" \
        -out "$cert_file" -keyout "$key_file" > /dev/null 2>&1

    echo "Self-signed SSL certificate created"
}


init_terraform() {
    (
        cd terraform

        if [ ! -d ".terraform" ]; then
            echo "Initializing Terraform backend..."
            terraform init
        fi
    )
}


apply_terraform() {
    echo "Provisioning resources with Terraform (this may take a while)..."

    pushd terraform > /dev/null

    terraform apply \
        -var "project=$PROJECT" \
        -var "cluster_name=$CLUSTER_NAME" \
        -var "username=$USERNAME" \
        -var "region=$REGION" \
        -var "eks_kubernetes_version=$EKS_KUBERNETES_VERSION" \
        -var "eks_instance_type=$EKS_INSTANCE_TYPE" \
        -var "eks_desired_nodes=$EKS_DESIRED_NODES" \
        -var "eks_min_nodes=$EKS_MIN_NODES" \
        -var "eks_max_nodes=$EKS_MAX_NODES" \
        -var "allowed_cidr=$PUBLIC_IP/32" \
        --auto-approve

    echo "Resources provisioned with Terraform"

    # obtain output
    VPC_ID=$(terraform output -raw vpc_id)
    if [[ -z "$VPC_ID" ]]; then
        echo "Failed to retrieve VPC ID. Exiting."
        popd > /dev/null
        exit 1
    fi

    AWS_LB_CONTROLLER_ROLE_ARN=$(terraform output -raw aws_lb_controller_role_arn)
    if [[ -z "$AWS_LB_CONTROLLER_ROLE_ARN" ]]; then
        echo "Failed to retrieve AWS Load Balancer Controller Role ARN. Exiting."
        popd > /dev/null
        exit 1
    fi

    ACM_CERTIFICATE_ARN=$(terraform output -raw acm_certificate_arn)
    if [[ -z "$ACM_CERTIFICATE_ARN" ]]; then
        echo "Failed to retrieve ACM Certificate ARN. Exiting."
        popd > /dev/null
        exit 1
    fi

    echo "Terraform outputs captured:"
    echo "VPC ID: $VPC_ID"
    echo "AWS Load Balancer Controller Role ARN: $AWS_LB_CONTROLLER_ROLE_ARN"
    echo "ACM Certificate ARN: $ACM_CERTIFICATE_ARN"

    popd > /dev/null

    sleep 10
}


update_kubectl_context() {
    echo "Updating kubectl config and selecting context..."
    aws eks --region $REGION update-kubeconfig --name $CLUSTER_NAME
    kubectl config use-context arn:aws:eks:$REGION:$AWS_ACCOUNT_ID:cluster/$CLUSTER_NAME
    echo "Current kubectl context:"
    kubectl config current-context
}


install_metrics_server() {
    echo "Installing Metrics Server..."
    kubectl apply -f "https://github.com/kubernetes-sigs/metrics-server/releases/download/$METRICS_SERVER_VERSION/components.yaml"
    
    echo "Waiting for API service to be ready..."
    kubectl wait --for=condition=Available apiservice/v1beta1.metrics.k8s.io --timeout=5m

    echo "Waiting for Metrics Server deployment to be ready..."
    kubectl wait --for=condition=available deployment/metrics-server -n kube-system --timeout=5m
}


install_load_balancer_controller_serviceaccount() {
    echo "Installing AWS Load Balancer Controller Service Account..."
    helm upgrade -i aws-lb-controller-serviceaccount-release "$HELM_DIR/aws-lb-controller-serviceaccount-chart" \
        --set "awsLoadBalancerControllerRoleArn=$AWS_LB_CONTROLLER_ROLE_ARN"
    sleep 10
    
    echo "Installing AWS Load Balancer Controller..."
    helm repo add eks https://aws.github.io/eks-charts
    helm repo update

    helm upgrade -i aws-load-balancer-controller eks/aws-load-balancer-controller \
        -n kube-system \
        --set "clusterName=$CLUSTER_NAME" \
        --set serviceAccount.create=false \
        --set serviceAccount.name=aws-load-balancer-controller-serviceaccount \
        --set "region=$REGION" \
        --set vpcId=$VPC_ID \
        --set "image.repository=602401143452.dkr.ecr.$REGION.amazonaws.com/amazon/aws-load-balancer-controller" \
        --set enableCertManager=false

    echo "Waiting for AWS Load Balancer Controller pods to be ready..."
    kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=aws-load-balancer-controller \
        -n kube-system --timeout=5m

    sleep 10  # for ensuring the aws-load-balancer-webhook-service webhook endpoint is ready   
}


install_ingress() {
    echo "Installing AWS ALB..."
    helm upgrade -i ingress-release "$HELM_DIR/ingress-chart" \
        --set "acmCertificateArn=$ACM_CERTIFICATE_ARN" \
        --set "uiServicePort=$UI_MODULE_PORT" \
        --set "backendServicePort=$BACKEND_MODULE_PORT"
}


get_alb_dns() {
    echo "Retrieving ALB DNS..."

    local retries=30
    local sleep_interval=5

    for ((i=1; i<=retries; i++)); do
        ALB_DNS=$(
            kubectl get ingress live-chat-ingress -o \
            jsonpath="{.status.loadBalancer.ingress[0].hostname}"
        )

        if [[ -n "$ALB_DNS" ]]; then
            echo "ALB DNS retrieved: $ALB_DNS"
            return 0
        fi

        echo "ALB DNS not available yet, retrying in $sleep_interval seconds... ($i/$retries)"
        sleep $sleep_interval
    done

    echo "Failed to retrieve ALB DNS after $retries attempts. Exiting."
    exit 1
}


install_ebs_csi_controller_serviceaccount() {
    helm upgrade -i ebs-csi-controller-serviceaccount-release "./helm/ebs-csi-controller-serviceaccount-chart" \
        --set "ebsCsiDriverRoleArn=$AWS_LB_CONTROLLER_ROLE_ARN"
}


install_redis_userstate_cluster() {
    echo "Installing Redis cluster for user state..."

    helm upgrade -i redis-userstate-release "./helm/redis-userstate-chart" \
        --set "redisVersion=$REDIS_VERSION" \
        --set "redisPort=$REDIS_PORT" \
        --set "redisClusterBusPort=$REDIS_CLUSTER_BUS_PORT" \
        --set "numRedisReplicasTotal=$NUM_REDIS_REPLICAS_TOTAL" \
        --set "redisStorageSize=$REDIS_STORAGE_SIZE" \
        --set "redisPassword=$REDIS_PASSWORD"
    sleep 5

    echo "Waiting for all pods to start..."
    while true; do
        local ready_pods=$(
            kubectl get pods -l app=redis-userstate \
            -o jsonpath='{.items[*].status.containerStatuses[?(@.name=="redis")].ready}' \
            | grep -o true | wc -l | xargs
        )
        if [ "$ready_pods" -eq "$NUM_REDIS_REPLICAS_TOTAL" ]; then
            echo "All $NUM_REDIS_REPLICAS_TOTAL Redis pods are ready!"
            break
        else
            echo "$ready_pods/$NUM_REDIS_REPLICAS_TOTAL pods are ready..."
            sleep 5
        fi
    done

    local cluster_status=$(
        kubectl exec redis-0 -- redis-cli -a "$REDIS_PASSWORD" cluster info \
        | grep cluster_state
    )
    if [[ "$cluster_status" == *"cluster_state:ok"* ]]; then
        echo "Redis Cluster is already set up. Skipping cluster creation."
        return 0
    fi

    # start cluster
    local redis_nodes=""
    for i in $(seq 0 $(($NUM_REDIS_REPLICAS_TOTAL - 1))); do
        local node="redis-$i.redis-userstate-service.default.svc.cluster.local:$REDIS_PORT"
        if [ -z "$redis_nodes" ]; then
            redis_nodes="$node"
        else
            redis_nodes="$redis_nodes $node"
        fi
    done
    echo "Starting cluster for nodes: $redis_nodes"
    
    kubectl exec redis-0 -c redis -- redis-cli \
        -a "$REDIS_PASSWORD" \
        --cluster create $redis_nodes \
        --cluster-replicas $NUM_REDIS_SLAVES_PER_MASTER \
        --cluster-yes
    
    echo "Redis cluster for user state installed"
    sleep 5
}


install_redis_messagebroker() {
    echo "Installing Redis deployment for message brokering..."
    helm upgrade -i redis-messagebroker-release "$HELM_DIR/redis-messagebroker-chart" \
        --set "redisPort=$REDIS_PORT" \
        --set "redisVersion=$REDIS_VERSION"
    
    echo "Waiting for the pod to be ready..."
    kubectl wait --for=condition=ready pod -l app=redis-messagebroker --timeout=5m

    echo "Redis deployment for message brokering installed"
    sleep 5
}


install_app() {
    echo "Installing application deployments..."
    helm upgrade -i app-release "$HELM_DIR/app-chart" \
        --set "awsAccountId=$AWS_ACCOUNT_ID" \
        --set "region=$REGION" \
        --set "backendEcrRepositoryName=$BACKEND_REPOSITORY_NAME" \
        --set "uiEcrRepositoryName=$UI_REPOSITORY_NAME" \
        --set "backendServicePort=$BACKEND_MODULE_PORT" \
        --set "backendMinReplicas=$BACKEND_MIN_REPLICAS" \
        --set "backendMaxReplicas=$BACKEND_MAX_REPLICAS" \
        --set "backendTargetCpuUtilization=$BACKEND_TARGET_CPU_UTILIZATION_PCT" \
        --set "backendMemoryRequest=$BACKEND_MEMORY_REQUEST" \
        --set "backendMemoryLimit=$BACKEND_MEMORY_LIMIT" \
        --set "backendCpuRequest=$BACKEND_CPU_REQUEST" \
        --set "backendCpuLimit=$BACKEND_CPU_LIMIT" \
        --set "uiServicePort=$UI_MODULE_PORT" \
        --set "uiMinReplicas=$UI_MIN_REPLICAS" \
        --set "uiMaxReplicas=$UI_MAX_REPLICAS" \
        --set "uiTargetCpuUtilization=$UI_TARGET_CPU_UTILIZATION_PCT" \
        --set "uiMemoryRequest=$UI_MEMORY_REQUEST" \
        --set "uiMemoryLimit=$UI_MEMORY_LIMIT" \
        --set "uiCpuRequest=$UI_CPU_REQUEST" \
        --set "uiCpuLimit=$UI_CPU_LIMIT" \
        --set "numRedisReplicasTotal=$NUM_REDIS_REPLICAS_TOTAL" \
        --set "redisPort=$REDIS_PORT" \
        --set "redisPassword=$REDIS_PASSWORD" \
        --set "albDns=$ALB_DNS" \
        --set "flaskSecretKey=$BASE64_SECRET_KEY"
    
    echo "Waiting for the pods to be ready (this may take a while)..."
    kubectl wait --for=condition=ready pod -l app=backend --timeout=5m
    kubectl wait --for=condition=ready pod -l app=ui --timeout=5m

    echo "Application deployments installed"
}


check_commands
check_aws_env
check_config_variables
compute_num_redis_replicas_total
encode_flask_secret
get_public_ip
get_aws_account_id
create_self_signed_ssl_cert
init_terraform
apply_terraform
update_kubectl_context
install_metrics_server
install_load_balancer_controller_serviceaccount
install_ingress
get_alb_dns

bash "$PUSH_IMAGE_SCRIPT" \
    "backend_module" \
    "$BACKEND_REPOSITORY_NAME" \
    "$BACKEND_DIR/Dockerfile" \
    "$BACKEND_DIR" \
    "$REGION"

bash "$PUSH_IMAGE_SCRIPT" \
    "ui_module" \
    "$UI_REPOSITORY_NAME" \
    "$UI_DIR/Dockerfile" \
    "$UI_DIR" \
    "$REGION"

install_ebs_csi_controller_serviceaccount
install_redis_userstate_cluster
install_redis_messagebroker
install_app

echo "Application launched successfully!"
echo -e "\n\033[1;32mAccess the application at: \033[1;34mhttps://$ALB_DNS\033[0m\n"
