#!/usr/bin/env bash
set -euo pipefail

# config
OUTDIR="./results"
JOB_TEMPLATE="deployment/load-driver-job-template.yaml"
PROM_URL="${PROM_URL:-http://localhost:9090}"  # set via env if needed
# experiment params
RPS_START=5
RPS_STEP=5
RPS_MAX=50            # change to desired max RPS
SPIN_START=100        # ms
SPIN_STEP=100         # ms
SPIN_MAX=500          # change as desired
RUN_DURATION="12m"    # total job duration
WARMUP_SECONDS=120    # discard first 2 minutes
FAIL_THRESHOLD=0.10   # stop when >10% failures

mkdir -p "${OUTDIR}"

echo "Experiment start: $(date)"
echo "Prometheus: ${PROM_URL}"

# helper to render job from template
render_job() {
  local rps=$1
  local spin=$2
  local duration=$3
  local outname="load-driver-${rps}rps-${spin}ms"
  sed -e "s/{{RPS}}/${rps}/g" \
      -e "s/{{SPIN}}/${spin}/g" \
      -e "s/{{DURATION}}/${duration}/g" \
      ${JOB_TEMPLATE} > /tmp/${outname}.yaml
  echo "/tmp/${outname}.yaml"
}

# main loops
for spin in $(seq ${SPIN_START} ${SPIN_STEP} ${SPIN_MAX}); do
  for rps in $(seq ${RPS_START} ${RPS_STEP} ${RPS_MAX}); do
    runname="${rps}rps-${spin}ms"
    echo "=== RUN: ${runname} ==="

    # cleanup previous job with same name if exists
    kubectl delete job "load-driver-${rps}rps-${spin}ms" --ignore-not-found=true

    JOB_YAML=$(render_job ${rps} ${spin} ${RUN_DURATION})
    kubectl apply -f "${JOB_YAML}"

    # wait for job to start and run for RUN_DURATION
    # wait until job active or succeeded
    echo "Waiting for job to start..."
    kubectl wait --for=condition=complete job/load-driver-${rps}rps-${spin}ms --timeout="${RUN_DURATION}" || true

    # Give an extra minute to ensure file flushed
    sleep 10

    # find job pod
    POD=$(kubectl get pods -l job-name=load-driver-${rps}rps-${spin}ms -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
    if [ -z "${POD}" ]; then
      echo "No pod found for job; marking run as failed."
      failures=1
      total=1
    else
      # copy results file if exists
      local_out="${OUTDIR}/results-${runname}.csv"
      kubectl exec ${POD} -- cat /out/results.csv > "${local_out}" || echo "No results.csv in pod"
      # parse CSV to count total and failures
      total=$(awk 'END{print NR-1}' "${local_out}" 2>/dev/null || echo 0)  # header excluded
      # count failures: last column == failure
      failures=$(awk -F, 'NR>1{ if($6=="failure") f++ } END{print f+0}' "${local_out}" 2>/dev/null || echo 0)
    fi

    if [ "${total}" -eq 0 ]; then
      fail_ratio=1.0
    else
      fail_ratio=$(awk "BEGIN{printf \"%.4f\", ${failures}/${total}}")
    fi

    echo "Run ${runname}: total=${total}, failures=${failures}, fail_ratio=${fail_ratio}"

    # collect prometheus metrics for interval: use start and end timestamps
    # determine job start and end times via pod timestamps
    if [ -n "${POD}" ]; then
      start_ts=$(kubectl get pod "${POD}" -o jsonpath='{.status.startTime}')
      # convert start time to epoch seconds
      start_epoch=$(date -d "${start_ts}" +%s)
      # run duration in seconds: parse RUN_DURATION (e.g., 12m)
      runsecs=$(echo ${RUN_DURATION} | awk '/m/{print int(substr($0,1,length($0)-1)*60)}')
      end_epoch=$((start_epoch + runsecs))
      # query Prometheus (example: worker requests, latency histogram)
      ./scripts/collect_prometheus.sh "${PROM_URL}" "${start_epoch}" "${end_epoch}" "${OUTDIR}/prometheus-${runname}.json" || echo "prometheus collect failed"
    fi

    # stop criteria
    # compare fail_ratio > FAIL_THRESHOLD
    cmp=$(awk "BEGIN{print (${fail_ratio} > ${FAIL_THRESHOLD})?1:0}")
    if [ "${cmp}" -eq 1 ]; then
      echo "Fail ratio ${fail_ratio} exceeded threshold ${FAIL_THRESHOLD}. Stopping sweep."
      exit 0
    fi

    # small pause between runs
    sleep 5
  done
done

echo "Experiment finished"
