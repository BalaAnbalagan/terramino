#!/usr/bin/env python3
import os, glob, csv
import matplotlib.pyplot as plt
def read_http_csv(path):
    rows = []
    with open(path, newline='') as f:
        r = csv.DictReader(f)
        for row in r:
            rows.append(row)
    return rows
def plot_http(csv_paths, out_png):
    ys = []
    for p in csv_paths:
        rows = read_http_csv(p)
        for row in rows:
            rps = row.get('req_per_sec')
            try:
                ys.append(float(rps) if rps else 0.0)
            except:
                ys.append(0.0)
    plt.figure()
    plt.title("HTTP Throughput (Requests/sec)")
    plt.plot(ys, marker='o')
    plt.xlabel("Run #")
    plt.ylabel("Req/sec")
    plt.grid(True)
    plt.tight_layout()
    os.makedirs(os.path.dirname(out_png), exist_ok=True)
    plt.savefig(out_png)
    print("Wrote", out_png)
def main():
    http_csvs = sorted(glob.glob("reports/benchmarks/http_*.csv"))
    if http_csvs:
        plot_http(http_csvs, "reports/charts/http_rps.png")
    else:
        print("No HTTP benchmark CSVs found")
if __name__ == "__main__":
    main()


def read_game_csv(path):
  rows = []
  import csv
  with open(path, newline='') as f:
    r = csv.DictReader(f)
    for row in r:
      rows.append(row)
  return rows

def plot_game(csv_paths):
  import matplotlib.pyplot as plt
  rps = []
  p95 = []
  for p in csv_paths:
    rows = read_game_csv(p)
    for row in rows:
      try:
        rps.append(float(row.get('rps','0')))
      except: rps.append(0.0)
      try:
        p95.append(float(row.get('p95_ms','0')))
      except: p95.append(0.0)
  if rps:
    plt.figure()
    plt.title("Game Throughput (RPS) — /api/new-game")
    plt.plot(rps, marker='o')
    plt.xlabel("Run #")
    plt.ylabel("Req/sec")
    plt.grid(True)
    plt.tight_layout()
    os.makedirs("reports/charts", exist_ok=True)
    plt.savefig("reports/charts/game_rps.png"); print("Wrote reports/charts/game_rps.png")
  if p95:
    plt.figure()
    plt.title("Game Latency P95 (ms) — /api/new-game")
    plt.plot(p95, marker='o')
    plt.xlabel("Run #")
    plt.ylabel("P95 (ms)")
    plt.grid(True)
    plt.tight_layout()
    os.makedirs("reports/charts", exist_ok=True)
    plt.savefig("reports/charts/game_p95.png"); print("Wrote reports/charts/game_p95.png")

def main_game():
  import glob
  game_csvs = sorted(glob.glob("reports/benchmarks/game_*.csv")) + \
              (["reports/benchmarks/game_results.csv"] if os.path.exists("reports/benchmarks/game_results.csv") else [])
  game_csvs = [p for p in game_csvs if os.path.isfile(p)]
  if game_csvs:
    plot_game(game_csvs)

# call additional chart generator
main_game()


def plot_boot(csv_path):
  import csv
  import matplotlib.pyplot as plt
  import os
  rows = []
  with open(csv_path, newline='') as f:
    r = csv.DictReader(f)
    for row in r:
      rows.append(row)
  if not rows: 
    return
  stacks = {}
  for row in rows:
    stack = row.get('stack','')
    try:
      t = float(row.get('t_total_ready_s','') or 'nan')
    except:
      t = float('nan')
    if stack:
      stacks.setdefault(stack, []).append(t)
  # average per stack
  labels = []
  vals = []
  for k,v in stacks.items():
    vals.append(sum([x for x in v if x==x])/len([x for x in v if x==x]))
    labels.append(k)
  if labels:
    plt.figure()
    plt.bar(labels, vals)
    plt.title("Time to Ready (s)")
    plt.ylabel("Seconds")
    plt.tight_layout()
    os.makedirs("reports/charts", exist_ok=True)
    plt.savefig("reports/charts/boot_ready_compare.png")
    print("Wrote reports/charts/boot_ready_compare.png")

def main_boot():
  import os
  p = "reports/boot/boot_times.csv"
  if os.path.exists(p):
    plot_boot(p)

main_boot()
