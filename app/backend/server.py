from flask import Flask, jsonify, request
import os, redis, time, threading, json

app = Flask(__name__)
redis_url = os.environ.get("REDIS_URL", "redis://redis:6379")
r = redis.from_url(redis_url, decode_responses=True)
start_time = time.time()

# Simple in-process counters for demo metrics
metrics_lock = threading.Lock()
games_created_total = 0
requests_total = 0
scores_submitted_total = 0
last_score = 0

@app.before_request
def _count_request():
    global requests_total
    with metrics_lock:
        requests_total += 1
@app.get("/health")
def health_alias(): return health()

@app.get("/new-game")
def new_game_alias(): return new_game()

@app.get("/api/health")
def health():
    try:
        pong = r.ping()
        return jsonify({"status":"ok","redis":pong}), 200
    except Exception as e:
        return jsonify({"status":"error","error":str(e)}), 500

@app.get("/metrics")
def metrics():
    uptime = int(time.time() - start_time)
    keys = r.dbsize()
    body = (
        f"terramino_uptime_seconds {uptime}\n"
        f"terramino_redis_keys {keys}\n"
        f"terramino_games_created_total {games_created_total}\n"
        f"terramino_requests_total {requests_total}\n"
        f"terramino_scores_submitted_total {scores_submitted_total}\n"
        f"terramino_last_score {last_score}\n"
    )
    return (body, 200, {"Content-Type":"text/plain; version=0.0.4"})

@app.get("/api/new-game")
def new_game():
    gid = int(time.time() * 1000)
    r.hset(f"game:{gid}", mapping={
        "state":"new",
        "score":"0",
        "lines":"0",
        "created_at":str(int(time.time()))
    })
    global games_created_total
    with metrics_lock:
        games_created_total += 1
    return jsonify({"game_id": gid})

@app.post("/api/score")
def submit_score():
    data = request.get_json(force=True, silent=True) or {}
    gid = str(data.get("game_id", ""))
    score = int(data.get("score", 0))
    lines = int(data.get("lines", 0))
    if not gid:
        return jsonify({"error":"missing_game_id"}), 400
    key = f"game:{gid}"
    if not r.exists(key):
        return jsonify({"error":"not_found"}), 404
    r.hset(key, mapping={"score": str(score), "lines": str(lines), "state":"running"})
    r.zadd("scores", {gid: score})
    global scores_submitted_total, last_score
    with metrics_lock:
        scores_submitted_total += 1
        last_score = score
    return jsonify({"ok": True, "game_id": int(gid), "score": score, "lines": lines}), 200

@app.get("/api/game/<int:gid>")
def get_game(gid):
    key = f"game:{gid}"
    if not r.exists(key):
        return jsonify({"error":"not_found"}), 404
    data = r.hgetall(key)
    data["game_id"] = gid
    return jsonify(data), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8081)
