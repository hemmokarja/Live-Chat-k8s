#!/bin/bash/

# before this: kubectl apply -f aws_load_balancer_controller_service_account.yaml

CLUSTER_NAME=LiveChatAppEKSCluster
REGION=eu-north-1
VPC_ID=vpc-072fa669b3c2538e4

helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm upgrade -i aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set "clusterName=$CLUSTER_NAME}" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set "region=$REGION" \
  --set vpcId=$VPC_ID \
  --set "image.repository=602401143452.dkr.ecr.$REGION.amazonaws.com/amazon/aws-load-balancer-controller" \
  --set enableCertManager=false

# check after installation: kubectl get pods -n kube-system
