<p align="center">
  <h1 align="center">KERNO</h1>
  <p align="center">
    <strong>eBPF-based kernel observability engine for Linux</strong>
  </p>
  <p align="center">
    <a href="https://github.com/lowplane/kerno/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/lowplane/kerno/actions/workflows/ci.yml/badge.svg"></a>
    <a href="https://goreportcard.com/report/github.com/lowplane/kerno"><img alt="Go Report Card" src="https://goreportcard.com/badge/github.com/lowplane/kerno"></a>
    <a href="LICENSE"><img alt="License: Apache 2.0" src="https://img.shields.io/badge/License-Apache_2.0-blue.svg"></a>
    <a href="https://github.com/lowplane/kerno/releases"><img alt="Release" src="https://img.shields.io/github/v/release/lowplane/kerno?include_prereleases"></a>
    <img alt="Go Version" src="https://img.shields.io/github/go-mod/go-version/lowplane/kerno">
  </p>
</p>

---

Kerno traces **syscall latency**, **TCP flows**, **OOM events**, **disk I/O**, **scheduler delays**, and **file descriptor leaks** in real-time using eBPF — then tells you exactly what's wrong in plain English.

One command. 30 seconds. Zero configuration.

```bash
sudo kerno doctor
```

```
╔═══════════════════════════════════════════════════════════╗
║                     KERNO DOCTOR                         ║
║          Kernel Diagnostic Report                        ║
╚═══════════════════════════════════════════════════════════╝

Host:     prod-db-01
Kernel:   6.8.0-generic

────────────────────────────────────────────────────────────
 FINDINGS  (2 critical · 1 warning · 0 info)
────────────────────────────────────────────────────────────

 !!  CRITICAL  TCP Retransmit Storm
     ──────────────────────────────
     Signal:   retransmit rate=12.3% (threshold: 2.0%), 847 retransmits
     Cause:    Network path degradation causing excessive retransmissions
     Impact:   Every connection risks latency spikes
     Fix:      → ethtool -S eth0 | grep -i error
               → ping -c 100 <gateway>

 !!  CRITICAL  Disk I/O Bottleneck Detected
     ─────────────────────────────────────
     Signal:   sync P99=280ms (threshold: 200ms), 3,241 sync ops
     Cause:    Storage device is saturated — fsync operations are blocking
     Impact:   Database writes and file syncs are delayed
     Fix:      → iostat -x 1 5
               → Consider faster storage or write batching

 !   WARNING   CPU Scheduler Contention
     ──────────────────────────────────
     Signal:   runqueue P99=18ms (warning: 5ms)
     Cause:    Processes waiting in the CPU run queue longer than expected
     Fix:      → top -H
               → Reduce worker threads or increase CPU count

────────────────────────────────────────────────────────────
 RECOMMENDED ACTION ORDER
────────────────────────────────────────────────────────────

  1. [NOW]     TCP Retransmit Storm
  2. [NOW]     Disk I/O Bottleneck Detected
  3. [5 MIN]   CPU Scheduler Contention

════════════════════════════════════════════════════════════
```

## Why Kerno

Every observability tool you use lives at the **application layer**. The kernel sees problems **first** — elevated syscall latency, TCP retransmits, memory pressure — minutes before your APM dashboard.

Kerno is the **missing layer**:

| | Layer | K8s Required | SLO Mapping | AI Analysis |
|---|---|:---:|:---:|:---:|
| Prometheus | Application | No | No | No |
| Datadog APM | Application | No | Partial | Yes |
| Inspektor Gadget | Container | **Yes** | No | No |
| **Kerno** | **Kernel** | **No** | **Yes** | **Yes** |

## Features

| Feature | Status | Description |
|---|:---:|---|
| `kerno doctor` | Done | 30-second automated kernel diagnostic with ranked findings |
| `kerno trace syscall` | Done | Real-time syscall latency streaming with top-N mode |
| `kerno trace disk` | Done | Block I/O latency tracing per device/operation/process |
| `kerno trace sched` | Done | CPU run queue delay monitoring with threshold filtering |
| `kerno watch tcp` | Done | Aggregated TCP connection monitoring (RTT, retransmits) |
| `kerno watch oom` | Done | OOM kill alerting with score threshold filtering |
| `kerno watch fd` | Done | FD leak detection via open/close growth rate |
| `kerno explain` | Done | AI-powered kernel error explanation (no root needed) |
| `kerno predict` | Done | Predict failures before they happen via trend analysis |
| `kerno start` | Done | Daemon mode with Prometheus metrics + health endpoints |
| Prometheus export | Done | `/metrics` endpoint with 16 kernel metrics |
| K8s enrichment | Done | Pod/namespace/node context via environment adapters |
| Helm chart | Done | `helm install kerno` with full DaemonSet deployment |
| AI-powered analysis | Done | Cross-signal correlation via Anthropic, OpenAI, or Ollama |
| Web dashboard | Planned | Real-time kernel signal visualization |
| SLO bridge | Planned | Map kernel signals to error budgets |

## Quick Start

### Prerequisites

- Linux kernel >= 5.8 with BTF support (`ls /sys/kernel/btf/vmlinux`)
- Root privileges (or `CAP_BPF` + `CAP_PERFMON`)

### Install

```bash
# From source
git clone https://github.com/lowplane/kerno.git
cd kerno
make build
sudo ./bin/kerno doctor
```

```bash
# Docker
docker run --privileged --pid=host \
  -v /sys/kernel/debug:/sys/kernel/debug:ro \
  -v /sys/fs/bpf:/sys/fs/bpf \
  -v /proc:/proc:ro \
  ghcr.io/lowplane/kerno:latest doctor
```

### Kubernetes

```bash
# Helm (recommended)
helm install kerno ./deploy/helm/kerno \
  -n kerno-system --create-namespace

# Or raw manifests
kubectl apply -f deploy/k8s/
```

## Usage

### Diagnostics

```bash
# 30-second kernel diagnostic
sudo kerno doctor

# Quick 10-second check
sudo kerno doctor --duration 10s

# JSON output for CI/CD (exits 1 on critical findings)
sudo kerno doctor --output json --exit-code

# AI-powered analysis (requires KERNO_AI_API_KEY)
sudo kerno doctor --ai

# Explain a kernel error — no root needed
kerno explain "BUG: kernel NULL pointer dereference, address: 0000000000000040"

# Explain from dmesg
dmesg | tail -5 | kerno explain

# Predict upcoming failures
sudo kerno predict --snapshots 5 --interval 15s
```

### Real-Time Tracing

```bash
# Stream all syscall events
sudo kerno trace syscall

# Filter by process
sudo kerno trace syscall --pid 1234

# Filter by syscall name, JSON output
sudo kerno trace syscall --filter read --output json

# Top 10 syscalls by p99 latency (refreshing)
sudo kerno trace syscall --top 10

# Trace disk I/O for a specific process
sudo kerno trace disk --process postgres

# Only writes above 5ms
sudo kerno trace disk --op write --threshold 5ms

# Scheduler delays above 10ms
sudo kerno trace sched --threshold 10ms

# Run for 60 seconds then exit
sudo kerno trace syscall --duration 60s
```

### Continuous Monitoring

```bash
# Watch TCP connections with retransmits
sudo kerno watch tcp --retransmits

# Only connections with RTT above 5ms
sudo kerno watch tcp --threshold-rtt 5ms --output json

# Watch for OOM kills with alert banner
sudo kerno watch oom --alert

# Only OOM events with score above 500
sudo kerno watch oom --threshold 500

# Detect FD leaks (processes opening >10 FDs/sec)
sudo kerno watch fd --threshold 10

# Daemon mode with Prometheus metrics
sudo kerno start

# Custom Prometheus address
sudo kerno start --prometheus-addr :9091
```

### Prometheus Metrics

When running `kerno start`, the following metrics are exposed at `:9090/metrics`:

| Metric | Type | Description |
|---|---|---|
| `kerno_syscall_duration_nanoseconds` | Summary | Syscall latency (p50, p95, p99) |
| `kerno_syscall_total` | Counter | Total syscall events |
| `kerno_tcp_rtt_nanoseconds` | Summary | TCP round-trip time |
| `kerno_tcp_retransmits_total` | Counter | TCP retransmissions |
| `kerno_tcp_connections_total` | Counter | TCP connection events |
| `kerno_oom_kills_total` | Counter | OOM kill events |
| `kerno_disk_io_duration_nanoseconds` | Summary | Disk I/O latency |
| `kerno_disk_io_bytes_total` | Counter | Disk I/O bytes |
| `kerno_sched_delay_nanoseconds` | Summary | CPU run queue delay |
| `kerno_fd_open_total` | Counter | FD open operations |
| `kerno_fd_close_total` | Counter | FD close operations |
| `kerno_collector_events_total` | Counter | Events per collector |
| `kerno_collector_errors_total` | Counter | Errors per collector |
| `kerno_bpf_programs_loaded` | Gauge | Loaded eBPF programs |
| `kerno_info` | Gauge | Build version info |

Health endpoints: `/healthz` and `/readyz` return JSON status.

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                   KERNEL SPACE (eBPF)                       │
│                                                             │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐      │
│  │ syscall  │ │   tcp    │ │   oom    │ │ disk_io  │      │
│  │ latency  │ │ monitor  │ │  track   │ │          │      │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘      │
│  ┌────┴─────┐ ┌────┴─────┐                                 │
│  │  sched   │ │ fd_track │                                  │
│  │  delay   │ │          │                                  │
│  └────┬─────┘ └────┬─────┘                                  │
│       │             │                                        │
│       └──────┬──────┘                                        │
│              ▼                                               │
│     ┌─────────────────┐                                      │
│     │   Ring Buffers   │  256KB per program, zero-copy       │
│     └────────┬────────┘                                      │
└──────────────┼──────────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────────┐
│                  USER SPACE (Go)                             │
│                                                              │
│  ┌────────────────┐    ┌──────────────────┐                  │
│  │  BPF Loaders   │───▶│  Metrics Bridge  │──▶ Prometheus    │
│  │  (cilium/ebpf) │    │  (decode + feed) │    :9090/metrics │
│  └───────┬────────┘    └──────────────────┘                  │
│          │                                                    │
│          ▼                                                    │
│  ┌────────────────┐    ┌──────────────────┐                  │
│  │   Collectors   │───▶│  Signals Struct  │                  │
│  │  (aggregation) │    │  (single snapshot│                  │
│  └────────────────┘    └───────┬──────────┘                  │
│                                │                              │
│                                ▼                              │
│                   ┌──────────────────────┐                    │
│                   │    Doctor Engine     │                    │
│                   │   (11 diag rules)   │                    │
│                   └──────────┬──────────┘                    │
│                              │                                │
│                              ▼                                │
│                   ┌──────────────────────┐                    │
│                   │  AI Layer (optional) │                    │
│                   │  Anthropic / OpenAI  │                    │
│                   │  Ollama (local)      │                    │
│                   └──────────┬──────────┘                    │
│                              │                                │
│                              ▼                                │
│                   ┌──────────────────────┐                    │
│                   │  Output: terminal,   │                    │
│                   │  JSON, Prometheus    │                    │
│                   └──────────────────────┘                    │
│                                                              │
│  ┌─────────────────────────────────────────────┐             │
│  │  Environment Adapter (auto-detected)        │             │
│  │  bare metal │ systemd │ kubernetes           │             │
│  │  Enriches events with hostname/pod/unit     │             │
│  └─────────────────────────────────────────────┘             │
└──────────────────────────────────────────────────────────────┘
```

Kerno uses **6 eBPF programs** attached to stable kernel tracepoints. Events flow through ring buffers to Go userspace, where they are aggregated into percentile distributions and analyzed by **11 diagnostic rules**. An optional **AI layer** enriches findings with cross-signal correlation and root cause analysis.

### Environment Adapters

Kerno automatically detects where it's running and enriches events:

| Environment | Detection | Enrichment |
|---|---|---|
| **Bare metal** | Default fallback | hostname, cgroup path |
| **Systemd** | `/proc/1/comm == systemd` | unit, slice, scope |
| **Kubernetes** | Service account token present | pod, namespace, node, deployment |

The K8s adapter maps cgroup paths to pod metadata via the Kubelet read-only API with a local cache refreshed every 30 seconds.

### AI Integration

AI sits **after** the deterministic rule engine — it enriches, never replaces:

- **3 providers:** Anthropic Claude, OpenAI, Ollama (local/air-gapped)
- **Privacy modes:** `full`, `redacted`, `summary` (default — only aggregates sent to LLM)
- **No LLM SDKs** — all providers use raw `net/http`
- **Graceful degradation** — AI failures are non-fatal, rule engine always works
- **Rate limiting + caching** — prevent excessive API calls in continuous mode

```bash
# Configure AI
export KERNO_AI_API_KEY="sk-..."
export KERNO_AI_PROVIDER="anthropic"  # or "openai" or "ollama"

sudo kerno doctor --ai
```

## Diagnostic Rules

| # | Rule | Trigger | Severity |
|---|------|---------|----------|
| 1 | Disk I/O Bottleneck | fsync P99 > 50ms or write P99 > 200ms | WARNING / CRITICAL |
| 2 | OOM Kill Occurred | Any OOM event in window | CRITICAL |
| 3 | TCP Retransmit Storm | Retransmit rate > 2% | CRITICAL |
| 4 | TCP RTT Degradation | RTT P99 > 10ms | WARNING |
| 5 | Scheduler Contention | Runqueue delay P99 > 5ms | WARNING / CRITICAL |
| 6 | FD Leak | FD growth > 10/sec sustained | WARNING (with ETA) |
| 7 | Syscall Latency High | Any syscall P99 > 100ms | WARNING / CRITICAL |
| 8 | OOM Imminent | Memory > 90% + positive growth | WARNING / CRITICAL (with ETA) |
| 9 | Syscall Error Rate | Error rate > 1% per syscall | WARNING / CRITICAL |
| 10 | Memory Pressure | RSS usage > 90% | WARNING |
| 11 | Network Latency | Connection RTT > 100ms | WARNING |

## Kubernetes Deployment

### Helm (Recommended)

```bash
helm install kerno ./deploy/helm/kerno \
  -n kerno-system --create-namespace
```

Customize via `values.yaml`:

```yaml
# Custom resource limits
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: "1"
    memory: 512Mi

# Enable Prometheus Operator ServiceMonitor
serviceMonitor:
  enabled: true
  interval: 15s

# Restrict to specific nodes
nodeSelector:
  monitoring: "true"

# Custom Prometheus port
prometheus:
  port: 9091
```

```bash
helm upgrade kerno ./deploy/helm/kerno \
  -n kerno-system -f my-values.yaml
```

### Raw Manifests

```bash
kubectl apply -f deploy/k8s/namespace.yaml
kubectl apply -f deploy/k8s/rbac.yaml
kubectl apply -f deploy/k8s/daemonset.yaml
kubectl apply -f deploy/k8s/service.yaml

# Optional: Prometheus Operator ServiceMonitor
kubectl apply -f deploy/k8s/servicemonitor.yaml

# Optional: PodDisruptionBudget
kubectl apply -f deploy/k8s/pdb.yaml
```

### Verify Deployment

```bash
# Check DaemonSet status
kubectl -n kerno-system get ds kerno

# Check pod logs
kubectl -n kerno-system logs -l app.kubernetes.io/name=kerno

# Scrape metrics
kubectl -n kerno-system port-forward ds/kerno 9090:9090
curl localhost:9090/metrics
```

## Configuration

Zero config required. For custom setups:

```yaml
# /etc/kerno/config.yaml
log_level: info
log_format: text

collectors:
  syscall_latency: true
  tcp_monitor: true
  oom_track: true
  disk_io: true
  sched_delay: true
  fd_track: true

doctor:
  duration: 30s
  thresholds:
    syscall_p99_warning_ns: 100000000   # 100ms
    syscall_p99_critical_ns: 500000000  # 500ms
    tcp_retransmit_pct: 2.0             # 2%
    oom_memory_pct: 90.0                # 90%
    disk_p99_warning_ns: 50000000       # 50ms
    disk_p99_critical_ns: 200000000     # 200ms
    sched_delay_warning_ns: 5000000     # 5ms
    sched_delay_critical_ns: 20000000   # 20ms
    fd_growth_per_sec: 10.0

prometheus:
  enabled: true
  addr: ":9090"

ai:
  enabled: false
  provider: anthropic       # anthropic, openai, ollama
  privacy_mode: summary     # full, redacted, summary
  cache_ttl: 5m
  rate_limit_per_minute: 10
```

Environment variables override config: `KERNO_LOG_LEVEL=debug`, `KERNO_AI_API_KEY=sk-...`, etc.

## Building from Source

```bash
# Requirements: Go 1.25+
# Optional for eBPF: clang 14+, libbpf-dev, llvm

# Build (uses stub BPF — works without clang)
make build

# Full build with eBPF compilation
make bpf && make build

# Run tests
make test

# Run tests with race detector
make test-race

# Run linter
make lint

# All quality checks (vet + test + lint)
make check

# Build Docker image
make docker
```

## Project Structure

```
kerno/
├── cmd/kerno/              # Binary entry point
├── internal/
│   ├── adapter/            # Environment adapters (baremetal, systemd, k8s)
│   ├── ai/                 # LLM provider abstraction (3 backends)
│   ├── bpf/                # eBPF loaders + Go event types
│   │   └── c/              # eBPF C programs + headers
│   ├── cli/                # Cobra CLI commands
│   ├── collector/           # Signal collection + aggregation
│   ├── config/              # Typed configuration (Viper)
│   ├── doctor/              # Diagnostic engine (rules + renderers)
│   ├── metrics/             # Prometheus metrics registry + bridge
│   └── version/             # Build metadata
├── deploy/
│   ├── k8s/                # Raw Kubernetes manifests
│   └── helm/kerno/         # Helm chart
├── docs/                    # Architecture documentation
├── Dockerfile               # Multi-stage container build
├── Makefile                 # Build orchestration
└── .goreleaser.yml          # Release automation
```

For detailed architecture documentation, see [docs/architecture.md](docs/architecture.md).

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for:

- Development setup and prerequisites
- Commit message conventions (Conventional Commits)
- Code review process
- DCO sign-off requirement

## Security

For vulnerability reports, see [SECURITY.md](SECURITY.md).

## License

Apache License 2.0 — see [LICENSE](LICENSE).

---

**Kerno** is built by [Shivam Kumar](https://github.com/btwshivam) at [Lowplane](https://github.com/lowplane).
