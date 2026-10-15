# es-refresh

Force [External Secrets Operator](https://external-secrets.io) to resync an ExternalSecret or re-validate a SecretStore now, instead of waiting for its refresh interval.

## Requirements

- Bash 3.2+
- `kubectl` on your `PATH`, with permission to annotate `externalsecrets` / `secretstores` in the target namespace
- External Secrets Operator installed in the cluster

## Install

None.

## Usage

```
es-refresh.sh -n <namespace> <type> <name>...

Types:
  es, externalsecret   re-fetch the secret from the provider
  ss, secretstore      re-validate the store's connection to the provider

Options:
  -n, --namespace <ns>   namespace of the resources (required)
      --context <ctx>    kubectl context to use (default: current context)
      --dry-run          print the kubectl command instead of running it
  -h, --help             show help and exit
```

Examples:

```bash
# Resync one ExternalSecret
es-refresh.sh -n payments es db-credentials

# Resync several at once
es-refresh.sh -n payments es db-credentials api-keys

# Re-validate a SecretStore on another cluster
es-refresh.sh -n payments ss vault-backend --context prod-eu-west-1

# See what would run
es-refresh.sh -n payments es db-credentials --dry-run
```

## How it works

It runs:

```bash
kubectl annotate --namespace <ns> externalsecrets.external-secrets.io <name>... force-sync=<unix time> --overwrite
```

Any change to an object's annotations makes the operator reconcile it. Using the current time as the value guarantees a change on every run.

- **ExternalSecret**: this is the [documented](https://external-secrets.io/latest/introduction/faq/) way to force a sync. The operator re-fetches the data from the provider and updates the Kubernetes Secret.
- **SecretStore**: not documented, but the SecretStore controller reconciles on any change to the object, and a reconcile re-validates the store against the provider and updates its `Ready` condition. Useful after fixing credentials or provider config.

Check the result with `kubectl get es -n <ns> <name>` (or `ss`), which shows the status and ready state.

## Notes

- Refreshing a SecretStore does **not** resync the ExternalSecrets that use it. Refresh those with `es`.
- Pods that read a secret as environment variables won't see new values until they restart. Secrets mounted as volumes update on their own, after a short delay.
- The namespace is required on purpose, so a refresh never lands in whatever namespace the current context defaults to.
- ClusterSecretStores and ClusterExternalSecrets aren't supported yet.
- Leaves a `force-sync` annotation on the resource; later runs overwrite it.
