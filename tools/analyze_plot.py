#!/usr/bin/env python3
import pandas as pd
import sys
import os
import numpy as np
import matplotlib.pyplot as plt

# usage: analyze_plot.py <results_dir> <runname>
# Or to aggregate many runs, point to a folder

if len(sys.argv) < 2:
    print("usage: analyze_plot.py <results_dir>")
    sys.exit(1)

results_dir = sys.argv[1]
out_png = os.path.join(results_dir, "summary.png")

rows = []
for root, dirs, files in os.walk(results_dir):
    for f in files:
        if f.endswith(".csv"):
            path = os.path.join(root, f)
            try:
                df = pd.read_csv(path)
            except Exception as e:
                print("skip", path, e)
                continue
            if 'timestamp' not in df.columns and 'timestamp_ms' not in df.columns:
                # accept both forms
                if 'timestamp_ms' in df.columns:
                    tscol = 'timestamp_ms'
                else:
                    tscol = df.columns[0]
            else:
                tscol = 'timestamp'
            # rename for safety
            df.columns = [c.strip() for c in df.columns]
            # assume columns: timestamp, rps, spin_ms, seq, latency_ms, success
            df = df[['timestamp', 'rps', 'spin_ms', 'seq', 'latency_ms', 'success']] if 'timestamp' in df.columns else df
            if df.shape[0] == 0:
                continue
            # convert types
            df['timestamp'] = pd.to_numeric(df['timestamp'])
            df['latency_ms'] = pd.to_numeric(df['latency_ms'])
            df['spin_ms'] = pd.to_numeric(df['spin_ms'])
            df['success'] = pd.to_numeric(df['success'])
            start_ts = df['timestamp'].min()
            # drop first 2 minutes = 120000 ms
            df = df[df['timestamp'] >= start_ts + 120000]
            if df.shape[0] == 0:
                continue
            total = len(df)
            failures = (df['success'] == 0).sum()
            success = total - failures
            mean_lat = df['latency_ms'].mean()
            p50 = df['latency_ms'].quantile(0.5)
            p95 = df['latency_ms'].quantile(0.95)
            spin = int(df['spin_ms'].iloc[0])
            slowdown = (mean_lat - spin) / spin if spin > 0 else None
            rows.append({
                'path': path,
                'rps': int(df['rps'].iloc[0]),
                'spin_ms': spin,
                'total': total,
                'failures': int(failures),
                'failure_rate': failures/total,
                'mean_latency_ms': mean_lat,
                'p50_ms': p50,
                'p95_ms': p95,
                'slowdown': slowdown
            })

if not rows:
    print("no data")
    sys.exit(1)

dfall = pd.DataFrame(rows)
print(dfall)
# Save summary CSV
dfall.to_csv(os.path.join(results_dir, "aggregated_summary.csv"), index=False)

# Plot slowdowns vs spin for each rps
import matplotlib.pyplot as plt
groups = dfall.groupby('rps')
plt.figure(figsize=(10,6))
for rps, g in groups:
    plt.plot(g['spin_ms'], g['slowdown'], marker='o', label=f"rps {rps}")
plt.xlabel("spin_ms")
plt.ylabel("slowdown (relative fraction)")
plt.title("Slowdown vs spin_ms for different RPS")
plt.legend()
plt.grid(True)
plt.savefig(out_png)
print("saved", out_png)
