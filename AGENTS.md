# Agents

`brewinfo` is a read-only Homebrew inventory for bash 3.2+ and zsh 5. The public repo is https://github.com/vmandic/bash-brewinfo

## Do not leak

Before a commit or a push, show the user the file list and wait.

Do not commit secrets. That means passwords, tokens, keys, and `.env` files.

`docs/example.jpg` is the example screenshot. Do not add a second copy, and do not paste a full `brewinfo` grid into Markdown.

`install.sh --write` writes a path under `$HOME` into the user's shell rc. Leave that on the machine. Do not copy the rc block into the repo.

## Install

Do not `curl | sh`. Do not `wget` the installer. Clone with git, then read `install.sh`.

```sh
git clone https://github.com/vmandic/bash-brewinfo.git
cd bash-brewinfo
./install.sh
```

`./install.sh` with no flags is a dry run. It must not change the rc file.

Run `./install.sh --write` or `./install.sh --uninstall` only after the user asks for that edit. Do not run it as root. The script exits if the uid is 0. Do not pass `--prefix` or `--rc` outside `$HOME`.

Sourcing the clone is enough when the user does not want files copied:

```sh
. /path/to/bash-brewinfo/share/brewinfo.zsh   # zsh
. /path/to/bash-brewinfo/share/brewinfo.bash  # bash
```

Use the path of the clone. Do not invent a home path in the repo.

## Behavior that must stay

- Never call `brew upgrade`, `brew install`, `brew uninstall`, or `brew tap`.
- Call `command brew`, not an alias.
- Set `HOMEBREW_NO_AUTO_UPDATE=1` and `HOMEBREW_NO_ENV_HINTS=1` only on those `brew` processes.
- Show an arrow only when the candidate version is newer. A lower number is not an upgrade.
- `(Nd)` is days since the keg was installed, from the receipt `time`. Do not invent a publish date for the latest version.
- Major: blood red `200,16,46`. Minor: yellow. Patch: default color.
- Reject names and versions that fall outside the character sets in the README. Do not `eval` brew output.
- Do not declare a zsh variable named `path`. It is tied to `PATH`.

## Checks

```sh
./test/run.sh
```

That test is offline. Do not commit a captured `brew` listing as a fixture.

## Commits

Commit only when the user asks. Do not invent a ticket id. Use a Conventional Commits subject and a body that says why.

Do not push unless the user asks. The remote is already public.
