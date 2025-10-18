#!/bin/bash
set -e

echo "Deploying..."

# Deploy Knative Worker
kubectl apply -f deployment/knative-worker.yaml

# Deploy Load Driver Job
kubectl apply -f deployment/load-driver-job.yaml

# Deploy metrics Service
kubectl apply -f deployment/worker-metrics-service.yaml

# Deploy ServiceMonitor for Prometheus
kubectl apply -f deployment/worker-servicemonitor.yaml
kubectl apply -f deployment/knative-autoscaler-servicemonitor.yaml

echo "Deployments applied."