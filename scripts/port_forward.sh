#!/bin/bash

# Kill previous port-forwards just in case
pkill -f "kubectl port-forward"

# Forward Grafana
echo "Starting Grafana port-forward..."
kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring &

# Forward Prometheus
echo "Starting Prometheus port-forward..."
kubectl port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090 -n monitoring &

wait

echo "Port-forwarding started:
Grafana: http://localhost:3000
Prometheus: http://localhost:9090"
