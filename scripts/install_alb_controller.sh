#!/bin/bash/

# before this: kubectl apply -f aws_load_balancer_controller_service_account.yaml

helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm upgrade -i aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=LiveChatAppEKSCluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=eu-north-1 \
  --set vpcId=vpc-0b8d569691d186060 \
  --set image.repository=602401143452.dkr.ecr.eu-north-1.amazonaws.com/amazon/aws-load-balancer-controller \
  --set enableCertManager=false

# check after installation: kubectl get pods -n kube-system
