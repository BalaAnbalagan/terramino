SHELL := /bin/bash
PY := python3

FRONTEND_URL ?= http://localhost:8080
BACKEND_URL  ?= http://localhost:8081
PROM_URL     ?= http://localhost:9090
GRAFANA_URL  ?= http://localhost:3000

.PHONY: test-docker-native test-vm-native bench-http-docker bench-http-vm bench-redis-docker bench-redis-vm charts \
	export-docker-images package-vagrant clean

test-docker-native:
	@echo "==> Functional tests (Docker-Native)"
	@OUT_JUNIT=reports/functional/results_docker.xml \
	FRONTEND_URL=$(FRONTEND_URL) BACKEND_URL=$(BACKEND_URL) PROM_URL=$(PROM_URL) GRAFANA_URL=$(GRAFANA_URL) \
	EXPECT_NODE=true EXPECT_CADVISOR=true \
	$(PY) tests/functional/test_functional.py

test-vm-native:
	@echo "==> Functional tests (VM-Native)"
	@OUT_JUNIT=reports/functional/results_vm.xml \
	FRONTEND_URL=$(FRONTEND_URL) BACKEND_URL=$(BACKEND_URL) PROM_URL=$(PROM_URL) GRAFANA_URL=$(GRAFANA_URL) \
	EXPECT_NODE=true EXPECT_CADVISOR=false \
	$(PY) tests/functional/test_functional.py

bench-http-docker:
	@echo "==> HTTP benchmark (Docker-Native)"
	URL=$(BACKEND_URL)/api/health ./tests/benchmark/http_bench.sh 100 15

bench-http-vm:
	@echo "==> HTTP benchmark (VM-Native)"
	URL=$(BACKEND_URL)/api/health ./tests/benchmark/http_bench.sh 100 15

bench-redis-docker:
	@echo "==> Redis benchmark (Docker-Native)"
	./tests/benchmark/redis_bench_docker.sh

bench-redis-vm:
	@echo "==> Redis benchmark (VM-Native)"
	./tests/benchmark/redis_bench_vm.sh

charts:
	$(PY) reports/charts.py

export-docker-images:
	./scripts/export-docker-images.sh

package-vagrant:
	./scripts/package-vagrant.sh

clean:
	rm -rf reports/functional/*.xml reports/benchmarks/*.csv reports/charts/*.png dist/*
