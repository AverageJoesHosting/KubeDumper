"""
KubeDumper - API Access Check
Author: KizzMyAnthia
Description:
    Checks for insecure API access for anonymous users in the specified namespaces.
"""

import os
from kubernetes import config
from modules.utils import log, prepare_output_directory, execute_shell_command

# Define the module's menu entry for dynamic CLI integration
MENU_ENTRY = {
    "command": "--check-api-access",
    "help": "Check for insecure API access by anonymous users.",
    "function": "check_api_access"
}

# ================================
# Permission Pre-check Function
# ================================
def check_permissions():
    """
    Verify the required permissions for executing the check.

    This function ensures the user has adequate permissions to list namespaces
    and impersonate the anonymous user to check API access permissions.
    """
    log("Verifying permissions for 'kubectl auth can-i'...", "INFO")

    # Check if the user can list namespaces
    list_namespaces_command = "kubectl auth can-i list namespaces"
    if execute_shell_command(list_namespaces_command) != 0:
        log("Insufficient permissions to list namespaces. Ensure your account has the necessary access.", "ERROR")
        exit(1)

    # Check if the user can impersonate anonymous access
    impersonate_anonymous_command = "kubectl auth can-i '*' '*' --as=system:anonymous"
    if execute_shell_command(impersonate_anonymous_command) != 0:
        log("Insufficient permissions to impersonate anonymous access. Verify your Kubernetes RBAC settings.", "ERROR")
        exit(1)

    log("Permissions verified successfully. Proceeding with the audit...", "INFO")

# ================================
# API Access Check Function
# ================================
def check_api_access(namespaces, dry_run=False, output_dir="/tmp/kubedumper-results"):
    """
    Check for insecure API access for anonymous users in the specified namespaces.

    :param namespaces: List of namespaces to check.
    :param dry_run: Whether to simulate execution.
    :param output_dir: Directory to save the results.
    """
    log("Checking API access for anonymous user...", "INFO")

    if not namespaces:
        log("No namespaces retrieved. Verify the cluster and your access permissions.", "ERROR")
        return

    for namespace in namespaces:
        log(f"Checking API access in namespace '{namespace}'...", "INFO")
        ns_dir = os.path.join(output_dir, namespace, "api_access")

        if dry_run:
            log(f"[DRY-RUN] Would create directory {ns_dir} and check API access in namespace '{namespace}'.", "WARN")
            continue

        prepare_output_directory(ns_dir)

        # Execute kubectl command to check permissions
        command = f"kubectl auth can-i '*' '*' --as=system:anonymous -n {namespace}"
        result_file = os.path.join(ns_dir, "insecure_api_access.txt")

        try:
            exit_code = execute_shell_command(command, output_file=result_file)
            if exit_code != 0:
                log(f"Failed to execute 'kubectl auth can-i' in namespace '{namespace}'. Check cluster connectivity and permissions.", "ERROR")
                os.remove(result_file)  # Clean up partial results
                continue

            # Analyze results
            with open(result_file, "r") as f:
                content = f.read()

            if "yes" in content:
                log(f"Anonymous user has broad permissions in namespace '{namespace}'. Results saved to: {result_file}", "WARN")
            else:
                log(f"Anonymous access is restricted in namespace '{namespace}'.", "SUCCESS")
                os.remove(result_file)  # Clean up since no issues were found

        except Exception as e:
            log(f"Error during API access check in namespace '{namespace}': {e}", "ERROR")

    log("Completed check_api_access.", "INFO")
