#!/usr/bin/env python3
"""
analyze_plot.py
- Reads CSVs in ./results/ with pattern results-<rps>rps-<spin>ms.csv
- Reads corresponding prometheus-<rps>rps-<spin>ms.json
- Produces:
  - latency_vs_rps.png (for each spin-ms)
  - overhead_heatmap.png (spin-ms x rps)
  - pods_vs_time_<run>.png
"""

import glob, os, re, pandas as pd, json
import matplotlib.pyplot as plt
import numpy as np

RESULT_DIR = "results"

def parse_csv(path):
    df = pd.read_csv(path)
    # assume columns: timestamp_ms, rps, spin_ms, seq, latency_ms, status
    # convert timestamp
    df['timestamp'] = pd.to_datetime(df['timestamp_ms'], unit='ms')
    return df

def load_prom_json(path):
    with open(path) as f:
        return json.load(f)

def overhead(latency_ms, spin_ms):
    # slowdown/overhead: (observed - requested)/requested
    return (latency_ms - spin_ms) / spin_ms

def main():
    files = sorted(glob.glob(os.path.join(RESULT_DIR, "results-*.csv")))
    if not files:
        print("No result CSVs found in", RESULT_DIR)
        return

    # parse run id from filename: results-<rps>rps-<spin>ms.csv
    runs = []
    for f in files:
        m = re.search(r"results-(\d+)rps-(\d+)ms\.csv", f)
        if not m: continue
        rps = int(m.group(1)); spin = int(m.group(2))
        df = parse_csv(f)
        # discard warmup first 2 minutes
        if not df.empty:
            start = df['timestamp'].min()
            cutoff = start + pd.Timedelta(minutes=2)
            df = df[df['timestamp'] >= cutoff]
        runs.append({'rps': rps, 'spin': spin, 'csv': f, 'df': df})
    # produce latency vs rps plot for each spin
    spins = sorted({r['spin'] for r in runs})
    for spin in spins:
        plt.figure()
        for r in sorted([x for x in runs if x['spin']==spin], key=lambda x: x['rps']):
            df = r['df']
            if df.empty:
                continue
            med = df['latency_ms'].median()
            p95 = df['latency_ms'].quantile(0.95)
            plt.plot(r['rps'], med, 'o', label=f"med rps={r['rps']}")
            plt.errorbar(r['rps'], med, yerr=[[med-p95],[p95-med]], fmt='o')
        plt.title(f"Latency vs RPS (spin={spin}ms)")
        plt.xlabel("RPS")
        plt.ylabel("latency_ms (median)")
        plt.grid(True)
        plt.savefig(os.path.join(RESULT_DIR, f"latency_vs_rps_{spin}ms.png"))
        plt.close()

    # Overhead heatmap: rows=spin, cols=rps
    rps_vals = sorted({r['rps'] for r in runs})
    spin_vals = sorted(spins)
    heat = np.full((len(spin_vals), len(rps_vals)), np.nan)
    for i,spin in enumerate(spin_vals):
        for j,rps in enumerate(rps_vals):
            match = next((x for x in runs if x['spin']==spin and x['rps']==rps), None)
            if not match or match['df'].empty:
                continue
            med_lat = match['df']['latency_ms'].median()
            heat[i,j] = (med_lat - spin) / spin
    # plot heatmap
    plt.figure(figsize=(10,6))
    plt.imshow(heat, aspect='auto', interpolation='nearest', cmap='viridis')
    plt.colorbar(label='overhead (fraction)')
    plt.xticks(range(len(rps_vals)), rps_vals)
    plt.yticks(range(len(spin_vals)), spin_vals)
    plt.xlabel('RPS')
    plt.ylabel('spin_ms')
    plt.title('Observed overhead (median latency - spin) / spin')
    plt.savefig(os.path.join(RESULT_DIR, 'overhead_heatmap.png'))
    plt.close()

    print("Plots saved under", RESULT_DIR)

if __name__ == "__main__":
    main()
