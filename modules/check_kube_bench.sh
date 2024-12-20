#!/bin/bash

# ================================
# Run CIS Kubernetes Benchmark with kube-bench
# ================================

check_kube_bench() {
    log "Running kube-bench scan for CIS Kubernetes Benchmark..." INFO

    for ns in $(get_namespaces); do
        log "Running kube-bench scan for namespace '$ns'..." INFO
        local ns_dir="$OUTPUT_DIR/$ns/kube_bench"

        if [ "$DRY_RUN" = "true" ]; then
            log "[DRY-RUN] Would create directory $ns_dir and run kube-bench scan for namespace '$ns'." WARN
            continue
        fi

        mkdir -p "$ns_dir" || { log "Error: Failed to create directory $ns_dir." ERROR; continue; }

        # Check if kube-bench is installed
        if ! command -v kube-bench &>/dev/null; then
            log "kube-bench is not installed. Cannot run CIS Kubernetes Benchmark checks for namespace '$ns'." ERROR
            log "Please install kube-bench to enable this check. See: https://github.com/aquasecurity/kube-bench" INFO
            continue
        fi

        # Run kube-bench scan with scored and unscored checks, save results in JSON and plain text
        log "Running kube-bench with scored and unscored checks for namespace '$ns'..." INFO
        kube-bench run --json > "$ns_dir/kube_bench_results.json" 2>/dev/null
        if [[ $? -eq 0 && -s "$ns_dir/kube_bench_results.json" ]]; then
            log "kube-bench JSON results saved to $ns_dir/kube_bench_results.json." SUCCESS
        else
            log "Failed to generate kube-bench JSON results or no results generated for namespace '$ns'." ERROR
            rm -f "$ns_dir/kube_bench_results.json"
        fi

        kube-bench run > "$ns_dir/kube_bench_results.txt" 2>/dev/null
        if [[ $? -eq 0 && -s "$ns_dir/kube_bench_results.txt" ]]; then
            log "kube-bench plain text results saved to $ns_dir/kube_bench_results.txt." SUCCESS
        else
            log "Failed to generate kube-bench plain text results or no results generated for namespace '$ns'." ERROR
            rm -f "$ns_dir/kube_bench_results.txt"
        fi
    done

    log "Completed kube-bench scan." SUCCESS
}
