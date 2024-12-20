#!/bin/bash

# ================================
# Check for Third-Party Image Deployment
# ================================

check_third_party_image() {
    log "Checking if third-party image can be deployed..." INFO
    log "Starting check_third_party_image." INFO
    local test_namespace="kubedumper-test"
    local test_pod="nginx-test-pod"

    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY-RUN] Would create a test pod using nginx image in namespace $test_namespace." WARN
        return
    fi

    # Create a test namespace if it doesn't exist
    log "Ensuring namespace $test_namespace exists." INFO
    kubectl create namespace "$test_namespace" 2>/dev/null || log "Namespace $test_namespace already exists." INFO

    # Attempt to create a test pod
    log "Creating test pod $test_pod in namespace $test_namespace." INFO
    kubectl run "$test_pod" --image=nginx --restart=Never -n "$test_namespace" 2>/dev/null
    if [ $? -ne 0 ]; then
        log "Failed to create test pod $test_pod. Check RBAC or cluster configuration." ERROR
        kubectl delete namespace "$test_namespace" --ignore-not-found >/dev/null 2>&1
        return
    fi

    # Wait for the pod to become ready
    log "Waiting for test pod $test_pod to become ready..." INFO
    kubectl wait --for=condition=Ready pod/"$test_pod" -n "$test_namespace" --timeout=30s >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        log "Test pod $test_pod deployed successfully. Third-party image deployment is allowed." SUCCESS
    else
        log "Test pod $test_pod failed to become ready. Third-party image deployment might be restricted." WARN
    fi

    # Clean up resources
    log "Cleaning up test resources..." INFO
    kubectl delete pod "$test_pod" -n "$test_namespace" --ignore-not-found >/dev/null 2>&1
    kubectl delete namespace "$test_namespace" --ignore-not-found >/dev/null 2>&1

    log "Completed check_third_party_image." SUCCESS
}
