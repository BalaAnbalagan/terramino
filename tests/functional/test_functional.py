#!/usr/bin/env python3
import os, sys, time, json
import xml.etree.ElementTree as ET
try:
    import requests
except Exception as e:
    print("ERROR: 'requests' is required. Install with: pip install requests", file=sys.stderr)
    sys.exit(2)

FRONTEND_URL = os.environ.get("FRONTEND_URL", "http://localhost:8080").rstrip("/")
BACKEND_URL  = os.environ.get("BACKEND_URL",  "http://localhost:8081").rstrip("/")
PROM_URL     = os.environ.get("PROM_URL",     "http://localhost:9090").rstrip("/")
GRAFANA_URL  = os.environ.get("GRAFANA_URL",  "http://localhost:3000").rstrip("/")

EXPECT_NODE      = os.environ.get("EXPECT_NODE", "true").lower() in ("1","true","yes","y")
EXPECT_CADVISOR  = os.environ.get("EXPECT_CADVISOR", "false").lower() in ("1","true","yes","y")
TIMEOUT_SEC      = float(os.environ.get("TIMEOUT", "5"))
OUT_JUNIT        = os.environ.get("OUT_JUNIT", "reports/functional/results.xml")

session = requests.Session()

class Suite:
    def __init__(self):
        self.cases = []
        self.failures = 0
        self.start = time.time()

    def test(self, name):
        def deco(fn):
            def wrapper():
                t0 = time.time()
                tc = {"name": name, "time": 0.0, "failure": None}
                try:
                    fn()
                except Exception as e:
                    tc["failure"] = str(e)
                    self.failures += 1
                finally:
                    tc["time"] = round(time.time() - t0, 3)
                    self.cases.append(tc)
            return wrapper
        return deco

    def write_junit(self, path):
        suite = ET.Element("testsuite", {
            "name": "Terramino Functional",
            "tests": str(len(self.cases)),
            "failures": str(self.failures),
            "time": f"{time.time()-self.start:.3f}"
        })
        for c in self.cases:
            tc = ET.SubElement(suite, "testcase", {"name": c["name"], "time": str(c["time"])})
            if c["failure"]:
                f = ET.SubElement(tc, "failure", {"message": c["failure"]})
                f.text = c["failure"]
        tree = ET.ElementTree(suite)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        tree.write(path, encoding="utf-8", xml_declaration=True)

S = Suite()

def _get(url, expect=200, contains=None):
    r = session.get(url, timeout=TIMEOUT_SEC)
    if r.status_code != expect:
        raise RuntimeError(f"GET {url} expected {expect} got {r.status_code}")
    if contains and contains not in r.text:
        raise RuntimeError(f"GET {url} missing expected text '{contains}'")
    return r

def _json(url, expect=200):
    r = session.get(url, timeout=TIMEOUT_SEC)
    if r.status_code != expect:
        raise RuntimeError(f"GET {url} expected {expect} got {r.status_code}")
    try:
        return r.json()
    except Exception:
        raise RuntimeError(f"GET {url} did not return JSON")

@S.test("frontend_root_serves")
def t1():
    _get(FRONTEND_URL + "/", 200)

@S.test("backend_health_ok")
def t2():
    j = _json(BACKEND_URL + "/api/health", 200)
    if isinstance(j, dict) and j.get("status") != "ok":
        raise RuntimeError(f"/api/health unexpected payload: {j}")

@S.test("proxy_health_ok")
def t3():
    _get(FRONTEND_URL + "/api/health", 200)

@S.test("backend_new_game")
def t4():
    r = session.get(BACKEND_URL + "/api/new-game", timeout=TIMEOUT_SEC)
    if r.status_code != 200:
        raise RuntimeError(f"/api/new-game status {r.status_code}")
    try:
        j = r.json()
    except Exception:
        raise RuntimeError("/api/new-game not JSON")
    if not isinstance(j, dict):
        raise RuntimeError("/api/new-game unexpected JSON type")

@S.test("prometheus_ready")
def t5():
    _get(PROM_URL + "/-/ready", 200)

@S.test("prometheus_targets_up")
def t6():
    r = session.get(PROM_URL + "/api/v1/targets?state=active", timeout=TIMEOUT_SEC)
    data = r.json()
    if data.get("status") != "success":
        raise RuntimeError("Prometheus API /targets not success")
    ups = {}
    for t in data["data"]["activeTargets"]:
        labels = t.get("labels", {})
        job = labels.get("job")
        health = t.get("health")
        if job:
            ups.setdefault(job, []).append(health)
    def assert_up(job, required):
        if required:
            if job not in ups or not all(h=='up' for h in ups[job]):
                raise RuntimeError(f"Prometheus job '{job}' not up: {ups.get(job)}")
    assert_up("backend", True)
    assert_up("redis", True)
    assert_up("node", EXPECT_NODE)
    assert_up("cadvisor", EXPECT_CADVISOR)

@S.test("grafana_login_page")
def t7():
    _get(GRAFANA_URL + "/login", 200)

if __name__ == "__main__":
    settle = float(os.environ.get("SETTLE_SEC", "0"))
    if settle > 0: time.sleep(settle)
    for fn in [t1,t2,t3,t4,t5,t6,t7]:
        fn()
    S.write_junit(OUT_JUNIT)
    print(f"Functional tests: {len(S.cases)} run, {S.failures} failed. JUnit: {OUT_JUNIT}")
    sys.exit(0 if S.failures == 0 else 1)
