#!/bin/bash

# ================================
# Check for HostPath Volume Mount
# ================================

check_host_path_mount() {
    log "Checking if hostPath volume can be mounted..." INFO
    log "Starting check_host_path_mount." INFO
    local test_namespace="kubedumper-test"
    local test_pod="hostpath-test-pod"

    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY-RUN] Would create a test pod with hostPath volume in namespace $test_namespace." WARN
        return
    fi

    # Create a test namespace if it doesn't exist
    log "Ensuring namespace $test_namespace exists." INFO
    kubectl create namespace "$test_namespace" 2>/dev/null || log "Namespace $test_namespace already exists." INFO

    # YAML for the test pod with a hostPath volume
    local test_pod_yaml=$(cat <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: $test_pod
  namespace: $test_namespace
spec:
  containers:
  - name: test-container
    image: busybox
    command: ["sh", "-c", "echo 'Hello from hostPath' > /test-volume/output.txt && sleep 30"]
    volumeMounts:
    - name: test-volume
      mountPath: /test-volume
  volumes:
  - name: test-volume
    hostPath:
      path: /tmp/hostpath-test
      type: DirectoryOrCreate
  restartPolicy: Never
EOF
)

    # Apply the test pod
    log "Creating test pod $test_pod in namespace $test_namespace." INFO
    echo "$test_pod_yaml" | kubectl apply -f - >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        log "Failed to create test pod $test_pod with hostPath volume. Check RBAC or cluster configuration." ERROR
        kubectl delete namespace "$test_namespace" --ignore-not-found >/dev/null 2>&1
        return
    fi

    # Wait for the pod to complete
    log "Waiting for test pod $test_pod to complete..." INFO
    kubectl wait --for=condition=Ready pod/"$test_pod" -n "$test_namespace" --timeout=30s >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        log "Test pod $test_pod successfully mounted the hostPath volume." SUCCESS
        # Verify output
        if kubectl exec "$test_pod" -n "$test_namespace" -- cat /test-volume/output.txt | grep -q "Hello from hostPath"; then
            log "HostPath volume is accessible and writable." SUCCESS
        else
            log "HostPath volume is not accessible or writable." WARN
        fi
    else
        log "Test pod $test_pod failed to become ready. HostPath volume mount might be restricted." WARN
    fi

    # Clean up resources
    log "Cleaning up test resources..." INFO
    kubectl delete pod "$test_pod" -n "$test_namespace" --ignore-not-found >/dev/null 2>&1
    kubectl delete namespace "$test_namespace" --ignore-not-found >/dev/null 2>&1
    rm -rf /tmp/hostpath-test

    log "Completed check_host_path_mount." SUCCESS
}
