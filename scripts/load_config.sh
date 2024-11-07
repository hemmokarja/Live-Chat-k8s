#!/bin/bash

# load project settings
PROJECT=$(yq ".project.name" config.yaml)
CLUSTER_NAME=$(yq ".project.cluster_name" config.yaml)
USERNAME=$(yq ".project.username" config.yaml)
REGION=$(yq ".project.region" config.yaml)

# load helm settings
AWS_LOAD_BALANCER_CONTROLLER_HELM_CHART_VERSION=$(yq ".helm.aws_load_balancer_controller_chart_version" config.yaml)

# load EKS settings
EKS_KUBERNETES_VERSION=$(yq ".eks.kubernetes_version" config.yaml)
METRICS_SERVER_VERSION=$(yq ".eks.metrics_server_version" config.yaml)
EKS_INSTANCE_TYPE=$(yq ".eks.instance_type" config.yaml)
EKS_DESIRED_NODES=$(yq ".eks.desired_nodes" config.yaml)
EKS_MIN_NODES=$(yq ".eks.min_nodes" config.yaml)
EKS_MAX_NODES=$(yq ".eks.max_nodes" config.yaml)

# load backend module settings
BACKEND_MIN_REPLICAS=$(yq ".backend_module.min_replicas" config.yaml)
BACKEND_MAX_REPLICAS=$(yq ".backend_module.max_replicas" config.yaml)
BACKEND_TARGET_CPU_UTILIZATION_PCT=$(yq ".backend_module.target_cpu_utilization_pct" config.yaml)
BACKEND_MEMORY_REQUEST=$(yq ".backend_module.memory_request" config.yaml)
BACKEND_MEMORY_LIMIT=$(yq ".backend_module.memory_limit" config.yaml)
BACKEND_CPU_REQUEST=$(yq ".backend_module.cpu_request" config.yaml)
BACKEND_CPU_LIMIT=$(yq ".backend_module.cpu_limit" config.yaml)
BACKEND_MODULE_PORT=$(yq ".backend_module.module_port" config.yaml)

# load UI module settings
UI_MIN_REPLICAS=$(yq ".ui_module.min_replicas" config.yaml)
UI_MAX_REPLICAS=$(yq ".ui_module.max_replicas" config.yaml)
UI_TARGET_CPU_UTILIZATION_PCT=$(yq ".ui_module.target_cpu_utilization_pct" config.yaml)
UI_MEMORY_REQUEST=$(yq ".ui_module.memory_request" config.yaml)
UI_MEMORY_LIMIT=$(yq ".ui_module.memory_limit" config.yaml)
UI_CPU_REQUEST=$(yq ".ui_module.cpu_request" config.yaml)
UI_CPU_LIMIT=$(yq ".ui_module.cpu_limit" config.yaml)
UI_MODULE_PORT=$(yq ".ui_module.module_port" config.yaml)

# load Redis settings
REDIS_VERSION=$(yq ".redis.version" config.yaml)
NUM_REDIS_MASTER_REPLICAS=$(yq ".redis.num_master_replicas" config.yaml)
NUM_REDIS_SLAVES_PER_MASTER=$(yq ".redis.num_slaves_per_master" config.yaml)
REDIS_STORAGE_SIZE=$(yq ".redis.storage_size" config.yaml)
REDIS_PORT=$(yq ".redis.port" config.yaml)
REDIS_CLUSTER_BUS_PORT=$(yq ".redis.cluster_bus_port" config.yaml)

# load RabbitMQ settings
RABBIT_VERSION=$(yq ".rabbitmq.version" config.yaml)
NUM_RABBIT_REPLICAS=$(yq ".rabbitmq.num_replicas" config.yaml)
RABBIT_PORT=$(yq ".rabbitmq.port" config.yaml)
RABBIT_DISCOVERY_PORT=$(yq ".rabbitmq.discovery_port" config.yaml)

echo "Configuration loaded successfully."
