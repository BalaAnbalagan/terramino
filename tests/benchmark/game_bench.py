#!/usr/bin/env python3
import os, sys, time, json, math, argparse, threading, queue, random
try:
    import requests
except Exception as e:
    print("ERROR: 'requests' is required. Install with: pip install requests", file=sys.stderr)
    sys.exit(2)

def percentile(latencies, p):
    if not latencies: return None
    latencies = sorted(latencies)
    k = (len(latencies)-1) * (p/100.0)
    f = math.floor(k); c = math.ceil(k)
    if f == c: return latencies[int(k)]
    d0 = latencies[f] * (c-k)
    d1 = latencies[c] * (k-f)
    return d0 + d1

def bench_new_game(target_base, duration_s, concurrency, out_csv):
    stop = time.time() + duration_s
    latencies = []
    total = 0
    ok = 0
    errors = 0
    lock = threading.Lock()
    session = requests.Session()
    def worker():
        nonlocal total, ok, errors
        while time.time() < stop:
            t0 = time.perf_counter()
            try:
                r = session.get(target_base.rstrip('/') + "/api/new-game", timeout=5)
                total += 1
                if r.status_code == 200:
                    try:
                        j = r.json()
                        if isinstance(j, dict) and ("game_id" in j or "id" in j or "gameId" in j):
                            with lock:
                                ok += 1
                        else:
                            with lock:
                                errors += 1
                    except Exception:
                        with lock:
                            errors += 1
                else:
                    with lock:
                        errors += 1
            except Exception:
                with lock:
                    errors += 1
            finally:
                dt_ms = (time.perf_counter() - t0) * 1000.0
                with lock:
                    latencies.append(dt_ms)

    threads = [threading.Thread(target=worker, daemon=True) for _ in range(concurrency)]
    for t in threads: t.start()
    for t in threads: t.join()

    elapsed = duration_s  # approximate, threads stop by deadline
    rps = ok / elapsed if elapsed > 0 else 0.0
    p50 = percentile(latencies, 50) or 0.0
    p95 = percentile(latencies, 95) or 0.0
    p99 = percentile(latencies, 99) or 0.0
    mean = sum(latencies)/len(latencies) if latencies else 0.0

    # write CSV
    import os
    os.makedirs(os.path.dirname(out_csv), exist_ok=True)
    header = "timestamp,target,endpoint,concurrency,duration_s,total_requests,success,errors,rps,p50_ms,p95_ms,p99_ms,mean_ms"
    write_header = not os.path.exists(out_csv)
    with open(out_csv, "a", encoding="utf-8") as f:
        if write_header:
            f.write(header + "\n")
        ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        row = f'{ts},{target_base},new-game,{concurrency},{duration_s},{total},{ok},{errors},{rps:.2f},{p50:.2f},{p95:.2f},{p99:.2f},{mean:.2f}'
        f.write(row + "\n")
    print(f"Wrote {out_csv}")
    print(f"new-game: ok={ok} err={errors} rps={rps:.2f} p95={p95:.2f}ms")

if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="Terramino game benchmark")
    ap.add_argument("--target", default=os.environ.get("BACKEND_URL","http://localhost:8081"), help="Base URL to backend (or frontend proxy)")
    ap.add_argument("--duration", type=int, default=int(os.environ.get("DURATION","15")))
    ap.add_argument("--concurrency", type=int, default=int(os.environ.get("CONCURRENCY","50")))
    ap.add_argument("--out", default=os.environ.get("OUT","reports/benchmarks/game_results.csv"))
    args = ap.parse_args()
    bench_new_game(args.target, args.duration, args.concurrency, args.out)
