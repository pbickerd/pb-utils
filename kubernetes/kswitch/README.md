# kswitch

Switch the current kubectl context, either by name or with a simple arrow-key picker.

## Requirements

- Bash 3.2+ (the macOS default is fine)
- `kubectl` on your `PATH`, with a kubeconfig containing one or more contexts
- For the prompt integration: bash or ksh93 (macOS `/bin/ksh`)

The picker is pure Bash (ANSI escape codes), so no `fzf` or other extra tools are needed.

## Install

None. Optionally put it on your `PATH`:

```bash
ln -s "$PWD/kswitch.sh" ~/.local/bin/kswitch
```

## Usage

```
kswitch.sh [options] [context]

  -l, --list       list contexts (current marked with *) and exit
  -c, --current    print the current context and exit
  -h, --help       show help and exit
```

Switch directly:

```bash
kswitch.sh prod-eu
```

Run with no arguments to open the picker, which starts on the current context:

| Key              | Action                              |
| ---------------- | ----------------------------------- |
| Up / Down, k / j | Move                                |
| Enter            | Switch to the highlighted context   |
| q / Esc          | Cancel (exit code 1, no change)     |

## Shell prompt

A script can't change the prompt of the shell that runs it, so prompt support comes from `kswitch-prompt.sh`, which you source. It defines a `kswitch` function that runs `kswitch.sh` and then puts the current context at the start of your prompt:

```
me@mac:~$ kswitch prod-eu-west-1
Switched to context "prod-eu-west-1"
(prod-eu-west-1) me@mac:~$ kswitch -r
me@mac:~$
```

| Command      | Action                                                  |
| ------------ | ------------------------------------------------------- |
| `kswitch …`  | Switch as normal, then show the context in the prompt   |
| `kswitch -p` | Show the context in the prompt without switching        |
| `kswitch -r` | Restore your original prompt                            |

The prompt reads `current-context` from your kubeconfig each time it's drawn (no `kubectl` call, so it's fast). It stays accurate if the context is changed another way, e.g. from another terminal.

### Setup

**bash**: add to `~/.bash_profile` on macOS (login shells don't read `~/.bashrc`), or `~/.bashrc` on Linux:

```bash
source /path/to/pb-utils/kubernetes/kswitch/kswitch-prompt.sh
```

**ksh**: interactive ksh reads the file named by `$ENV`. In `~/.profile`:

```sh
export ENV=$HOME/.kshrc
```

and in `~/.kshrc`:

```sh
. /path/to/pb-utils/kubernetes/kswitch/kswitch-prompt.sh
```

`kswitch-prompt.sh` finds `kswitch.sh` in its own folder. If you move one of them, set `KSWITCH_BIN` to the path of `kswitch.sh` before sourcing.

## Notes

- Changes `current-context` in your kubeconfig (`kubectl config use-context`), so it affects every shell using that kubeconfig, not only the current one.
- With no context given and no terminal attached (e.g. in a pipe or cron job), it exits with an error rather than prompting.
- On bash 3.2 (macOS default), a plain Esc takes about a second to cancel the picker, because that bash only supports whole-second read timeouts. `q` is instant.
- Prompt frameworks that rebuild `PS1` on every prompt via `PROMPT_COMMAND` (e.g. starship, some themes) will overwrite the context segment.
- `kswitch -r` restores the prompt as it was when the segment was first added; changes made to `PS1` in between are lost.
