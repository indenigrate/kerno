#!/usr/bin/env bash
# Copyright 2026 Optiqor contributors
# SPDX-License-Identifier: Apache-2.0
#
# verify.sh — end-to-end production-readiness check for kerno.
#
# Runs chaos in the background, kerno doctor in the foreground, and
# asserts that the paired diagnostic rule fires. Repeats for each
# (scenario, paired_rule) pair so we have proof that "induce → detect"
# works for every doctor rule we ship.
#
# Requires: sudo (for eBPF), bin/kerno, bin/bpf-verify.
#
# Usage:
#   ./scripts/verify.sh             # run all pairings
#   ./scripts/verify.sh disk-sat    # run a single scenario

set -euo pipefail

cd "$(dirname "$0")/.."

KERNO=bin/kerno

if [[ ! -x "$KERNO" ]]; then
    echo "==> Building kerno..."
    make build >/dev/null
fi

# Build bpf-verify if missing.
if [[ ! -x bin/bpf-verify ]]; then
    echo "==> Building bpf-verify..."
    go build -o bin/bpf-verify ./cmd/bpf-verify
fi

# All scenario → expected-rule pairings.
# Format: "scenario:expected_rule"
PAIRINGS=(
    "disk-sat:disk_io_bottleneck"
    "fd-leak:fd_leak"
    "cpu:scheduler_contention"
    "tcp-churn:scheduler_contention"
)

# Allow filtering to one scenario via $1.
if [[ $# -gt 0 ]]; then
    FILTER="$1"
    NEW=()
    for p in "${PAIRINGS[@]}"; do
        if [[ "${p%%:*}" == "$FILTER" ]]; then
            NEW+=("$p")
        fi
    done
    PAIRINGS=("${NEW[@]}")
    if [[ ${#PAIRINGS[@]} -eq 0 ]]; then
        echo "Unknown scenario: $FILTER" >&2
        echo "Valid: disk-sat, fd-leak, cpu, tcp-churn" >&2
        exit 1
    fi
fi

# ─── verifier preflight ────────────────────────────────────────────────────
echo "==> Step 1: BPF verifier preflight"
sudo bin/bpf-verify >/tmp/verify-bpf.log 2>&1
ok=$(grep -c "VERIFIER OK" /tmp/verify-bpf.log || true)
if [[ "$ok" -lt 6 ]]; then
    echo "    FAIL: only $ok/6 programs passed the verifier"
    cat /tmp/verify-bpf.log
    exit 1
fi
echo "    OK: 6/6 BPF programs pass the verifier"
echo

# ─── induce → detect pairings ──────────────────────────────────────────────
PASS=0
FAIL=0
for pairing in "${PAIRINGS[@]}"; do
    scenario="${pairing%%:*}"
    expected_rule="${pairing##*:}"

    echo "==> Step 2.${scenario}: induce $scenario → expect $expected_rule"

    # Start chaos in background; redirect output to keep stdout clean.
    "$KERNO" chaos --induce "$scenario" --duration 12s --intensity high --yes \
        >/tmp/verify-chaos-"$scenario".log 2>&1 &
    chaos_pid=$!

    # Give chaos 1s head start.
    sleep 1

    # Run doctor with the verify-tuned config (looser thresholds so
    # synthetic chaos on fast hardware trips the rules).
    sudo "$KERNO" --config scripts/verify-config.yaml \
        doctor --duration 10s --output json \
        >/tmp/verify-doctor-"$scenario".json 2>/tmp/verify-doctor-"$scenario".log

    # Wait for chaos to finish.
    wait $chaos_pid 2>/dev/null || true

    # Check doctor output for the expected rule.
    if jq -e --arg r "$expected_rule" '.findings[] | select(.rule == $r)' \
        /tmp/verify-doctor-"$scenario".json >/dev/null 2>&1; then
        sev=$(jq -r --arg r "$expected_rule" \
            '.findings[] | select(.rule == $r) | .severity' \
            /tmp/verify-doctor-"$scenario".json | head -1)
        echo "    PASS: rule $expected_rule fired (severity: $sev)"
        PASS=$((PASS+1))
    else
        echo "    FAIL: rule $expected_rule did not fire"
        echo "    rules that did fire:"
        jq -r '.findings[] | "      - \(.rule) (\(.severity))"' \
            /tmp/verify-doctor-"$scenario".json 2>/dev/null || \
            echo "      (could not parse doctor JSON)"
        FAIL=$((FAIL+1))
    fi
    echo
done

# ─── summary ───────────────────────────────────────────────────────────────
echo "==> Verification Summary"
echo "    BPF verifier:  6/6 programs"
echo "    Rule firing:   $PASS/${#PAIRINGS[@]} pairings"

if [[ $FAIL -gt 0 ]]; then
    echo "    OVERALL:       FAIL"
    echo
    echo "Logs in /tmp/verify-*.log /tmp/verify-*.json"
    exit 1
fi

echo "    OVERALL:       PASS"
