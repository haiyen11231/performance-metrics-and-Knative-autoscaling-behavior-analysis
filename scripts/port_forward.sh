#!/bin/bash
# Forward Prometheus and Grafana ports
kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring &
kubectl port-forward svc/grafana 3000:80 -n monitoring &

wait 

echo "Port-forwarding started: Prometheus: http://localhost:9090, Grafana: http://localhost:3000"
