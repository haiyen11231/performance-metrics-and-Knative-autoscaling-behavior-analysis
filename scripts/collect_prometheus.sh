#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 4 ]; then
  echo "usage: $0 PROM_URL START_EPOCH END_EPOCH OUT_JSON"
  exit 2
fi

PROM_URL="$1"
START="$2"
END="$3"
OUT="$4"

STEP="15s"

# queries (adjust metric names if different)
Q1='sum(rate(worker_requests_total[1m]))'  # request rate
Q2='histogram_quantile(0.95, sum(rate(worker_request_latency_ms_bucket[5m])) by (le))'
Q3='sum(rate(load_driver_requests_total[1m]))'  # client-side RPS
Q4='autoscaler_actual_pods{service_name="worker"}'  # Knative KPA metric; may vary by installation

# helper for query_range
fetch() {
  local q=$1
  local name=$2
  local url="${PROM_URL}/api/v1/query_range?query=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''${q}'''))")&start=${START}&end=${END}&step=${STEP}"
  curl -s "${url}" | jq -c --arg name "${name}" '{"name":$name, "result":.}' 
}

# produce a JSON array of results
echo "[" > "${OUT}"
fetch "${Q1}" "req_rate" >> "${OUT}"
echo "," >> "${OUT}"
fetch "${Q2}" "latency_p95" >> "${OUT}"
echo "," >> "${OUT}"
fetch "${Q3}" "client_rps" >> "${OUT}"
echo "," >> "${OUT}"
fetch "${Q4}" "actual_pods" >> "${OUT}"
echo "]" >> "${OUT}"

echo "Prometheus data saved to ${OUT}"
