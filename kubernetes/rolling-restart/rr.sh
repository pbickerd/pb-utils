#!/usr/bin/env bash
#
# rr.sh - rolling restart of a Kubernetes deployment, statefulset or daemonset.

set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") -n <namespace> <resource-type> <resource-name>

Trigger a rolling restart of a workload. Equivalent to:

  kubectl -n <namespace> rollout restart <resource-type> <resource-name>

<resource-type> is anything kubectl rollout accepts: deploy/deployment,
sts/statefulset or ds/daemonset.

Options:
  -n, --namespace <ns>   namespace of the resource (required)
      --context <ctx>    kubectl context to use (default: current context)
      --dry-run          print the kubectl command without running it
  -h, --help             show this help and exit

Examples:
  $(basename "$0") -n myapp deploy my-app
  $(basename "$0") -n data sts postgres --context prod
EOF
}

die() {
  printf 'rr: %s\n' "$*" >&2
  exit 1
}

main() {
  local namespace='' context='' dry_run=0 args=()

  while (($#)); do
    case $1 in
      -h | --help)
        usage
        exit 0
        ;;
      -n | --namespace)
        (($# >= 2)) || die "$1 needs a value"
        namespace=$2
        shift
        ;;
      --context)
        (($# >= 2)) || die "$1 needs a value"
        context=$2
        shift
        ;;
      --dry-run) dry_run=1 ;;
      -*) die "unknown option: $1 (see --help)" ;;
      *) args+=("$1") ;;
    esac
    shift
  done

  [[ -n $namespace ]] || die "namespace is required: -n <namespace> (see --help)"
  ((${#args[@]} == 2)) || die "expected <resource-type> <resource-name> (see --help)"

  local kubectl=(kubectl)
  if [[ -n $context ]]; then
    kubectl+=(--context "$context")
  fi
  kubectl+=(--namespace "$namespace" rollout restart "${args[0]}" "${args[1]}")

  if ((dry_run)); then
    printf '%s\n' "${kubectl[*]}"
    exit 0
  fi

  command -v kubectl >/dev/null || die "kubectl not found in PATH"
  "${kubectl[@]}"
}

main "$@"
