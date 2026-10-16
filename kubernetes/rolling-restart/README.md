# rolling-restart

`rr.sh` — trigger a rolling restart of a deployment, statefulset or daemonset. Shorthand for `kubectl -n <namespace> rollout restart <type> <name>`.

## Requirements

- Bash 3.2+
- `kubectl` on your `PATH`, with permission to patch the target resource

## Install

None.

## Usage

```
rr.sh -n <namespace> <resource-type> <resource-name>

  -n, --namespace <ns>   namespace of the resource (required)
      --context <ctx>    kubectl context to use (default: current context)
      --dry-run          print the kubectl command without running it
  -h, --help             show help and exit
```

`<resource-type>` is anything `kubectl rollout` accepts: `deploy`/`deployment`, `sts`/`statefulset` or `ds`/`daemonset`.

Restart a deployment:

```bash
rr.sh -n myapp deploy my-app
```

Restart a statefulset in another context:

```bash
rr.sh -n data sts postgres --context prod
```

Check what would run:

```
$ rr.sh -n myapp deploy my-app --dry-run
kubectl --namespace myapp rollout restart deploy my-app
```

## Notes

- Pods are replaced according to the resource's update strategy, so the restart is rolling as long as there is more than one replica. A single-replica workload will have a short gap (or none, for a deployment with `maxSurge` > 0).
- The command returns as soon as the restart is triggered; it doesn't wait for the rollout. Use `kubectl -n <namespace> rollout status <type> <name>` to watch it.
