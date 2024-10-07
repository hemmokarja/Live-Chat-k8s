#!/bin/bash

kubectl apply -f flask-secret.yaml
kubectl apply -f redis-deployment.yaml
kubectl apply -f backend-deployment.yaml
kubectl apply -f ui-deployment.yaml
