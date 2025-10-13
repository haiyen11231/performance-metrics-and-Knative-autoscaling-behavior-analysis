#!/usr/bin/env bash
set -euo pipefail

# Config
DRIVER_POD_LABEL="app=load-driver"
OUTDIR="./results"
mkdir -p "$OUTDIR"

# parameters
RPS_START=5
RPS_STEP=5
SPIN_START=100   # ms
SPIN_STEP=100    # ms

# function to start driver with given params by patching args
run_config() {
  local rps=$1
  local spin=$2
  local runname="rps${rps}_spin${spin}"
  echo "=== RUN $runname ==="

  # Patch the driver deployment args; simpler approach: create a new job pod instead.
  # We'll create a temporary Pod to run the driver CLI and write CSV to /out via volume.
  kubectl delete pod -l run=$runname --ignore-not-found
  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: driver-${runname}
  labels:
    run: ${runname}
spec:
  nodeSelector:
    kubernetes.io/hostname: "node-0"
  restartPolicy: Never
  containers:
    - name: driver
      image: YOUR_DOCKERHUB_USER/load-driver:latest
      command: ["/usr/local/bin/driver"]
      args: ["--target", "worker-fn.default.svc.cluster.local:50051", "--rps", "${rps}", "--duration", "12m", "--spin-ms", "${spin}", "--out", "/out/${runname}.csv"]
      volumeMounts:
        - name: out
          mountPath: /out
  volumes:
    - name: out
      emptyDir: {}
EOF

  # Wait until pod running
  kubectl wait --for=condition=Ready pod/driver-${runname} --timeout=60s || true

  # Wait for completion (pod terminates after duration)
  echo "Waiting for driver pod to finish (12m) for $runname..."
  kubectl wait --for=condition=Succeeded pod/driver-${runname} --timeout=13m || {
    echo "driver pod did not finish; deleting and retrieving logs"
    kubectl logs pod/driver-${runname} --all-containers || true
    kubectl delete pod driver-${runname} --force --grace-period=0 || true
  }

  # copy csv
  mkdir -p "${OUTDIR}/${runname}"
  kubectl cp default/driver-${runname}:/out/${runname}.csv "${OUTDIR}/${runname}/results.csv" || true

  # compute failure rate from CSV (simple)
  if [ -f "${OUTDIR}/${runname}/results.csv" ]; then
    failures=$(awk -F, 'NR>1{ if($6=="0") f++ ; t++ } END{ if(t==0) print 0; else print (f/t)*100 }' "${OUTDIR}/${runname}/results.csv")
    echo "Failure rate: ${failures}%"
  else
    echo "No result CSV found for $runname"
    failures=100
  fi

  echo "$runname,$failures" >> "${OUTDIR}/summary.csv"

  # return failure percentage
  echo "$failures"
}

# main sweep: nested loops
rps=${RPS_START}
while true; do
  spin=${SPIN_START}
  while true; do
    failures=$(run_config $rps $spin)
    # check failure threshold > 10 -> terminate and stop further increasing spin for this rps
    failures=${failures%.*} # integer part
    if [ "$failures" -gt 10 ]; then
      echo "Failures exceed 10% at rps $rps spin $spin -> stop this rps"
      break
    fi
    spin=$((spin + SPIN_STEP))
    # you may put a limit on spin to avoid infinite loops
    if [ $spin -gt 2000 ]; then
      echo "spin too high, stopping"
      break
    fi
  done
  rps=$((rps + RPS_STEP))
  if [ $rps -gt 200 ]; then
    echo "rps too high, done"
    break
  fi
done

echo "Finished sweep. Summary at ${OUTDIR}/summary.csv"

# The runner creates a one-off Pod on node-0 to run the load-driver binary for 12 minutes and then copy out the CSV. This is simpler than editing Deployment arguments live.

# The runner checks failure rate > 10% to stop increasing spin for a given RPS and then moves to next RPS.

# Tweak limits, timeouts, and retries as needed.