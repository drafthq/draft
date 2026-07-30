#!/usr/bin/env bash
# Benchmark for skill-order membership check optimization
# Compares O(N*M) nested loop vs O(N) associative array lookup

set -euo pipefail

# Generate synthetic data
# N = Number of skills in SKILL_ORDER
# M = Number of skills on disk
N=1000
M=1000

SKILL_ORDER=()
for ((i=0; i<N; i++)); do
    SKILL_ORDER+=("skill_$i")
done

DISK_SKILLS=()
for ((i=0; i<M; i++)); do
    DISK_SKILLS+=("skill_$i")
done

# Shuffle DISK_SKILLS to simulate real-world scenarios (optional but better)
# For simplicity, we just use them as is.

echo "Benchmarking with N=$N (SKILL_ORDER) and M=$M (DISK_SKILLS)"
echo "--------------------------------------------------------"

# O(N*M) Nested Loop
benchmark_nested_loop() {
    local start_time
    start_time=$(date +%s%N)
    local ALL_DISK_IN_ORDER=true
    for disk_skill in "${DISK_SKILLS[@]}"; do
        local FOUND=false
        for order_skill in "${SKILL_ORDER[@]}"; do
            if [[ "$disk_skill" == "$order_skill" ]]; then
                FOUND=true
                break
            fi
        done
        if [[ "$FOUND" == "false" ]]; then
            ALL_DISK_IN_ORDER=false
        fi
    done
    local end_time
    end_time=$(date +%s%N)
    echo "Nested Loop: $(((end_time - start_time) / 1000000)) ms (ALL_DISK_IN_ORDER=$ALL_DISK_IN_ORDER)"
}

# O(N) Associative Array
benchmark_assoc_array() {
    local start_time
    start_time=$(date +%s%N)

    # Pre-populate associative array for O(1) lookups
    declare -A ORDER_MAP
    for skill in "${SKILL_ORDER[@]}"; do
        ORDER_MAP["$skill"]=1
    done

    local ALL_DISK_IN_ORDER=true
    for disk_skill in "${DISK_SKILLS[@]}"; do
        if [[ -z "${ORDER_MAP["$disk_skill"]:-}" ]]; then
            ALL_DISK_IN_ORDER=false
        fi
    done
    local end_time
    end_time=$(date +%s%N)
    echo "Assoc Array: $(((end_time - start_time) / 1000000)) ms (ALL_DISK_IN_ORDER=$ALL_DISK_IN_ORDER)"
}

benchmark_nested_loop
benchmark_assoc_array
