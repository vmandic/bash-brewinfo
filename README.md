# brewinfo

`brewinfo` prints installed Homebrew formulae and casks in columns, the same way `brew list` does. Each name is followed by the installed version. If Homebrew has a newer version, the line adds an arrow and that version.

```
ffmpeg@8.1.1 (400d) -> 9.0.2_1
aom@3.13.3 (20d) -> 3.15.3
vlc@3.0.21 (700d) -> 3.0.24
dotnet@11.0.100 (3d)
```

`(Nd)` is how many days ago this Mac installed that version. It is not the upstream publish date. There is no day count on the version after the arrow. A missing receipt means no `(Nd)`.

It does not install, upgrade, or remove anything.

## Example

![brewinfo grid: formulae and casks with versions and install age. Major upgrades and ages over 365 days are red. Minor upgrades and ages over 180 days are yellow.](docs/example.jpg)

That image is a real `brewinfo` run on one Mac. It shows formula names, cask names, versions, and `(Nd)` install age. It does not show a home directory, a username, a hostname, an email address, or any credential. If you publish this repository, that package list is part of the publication. Delete `docs/example.jpg` first if you do not want that list public.

## Colors

The arrow is shown only when the Homebrew version is newer than the installed one.

| Change | Latest version |
| --- | --- |
| Major (first number) | Blood red, RGB 200, 16, 46 |
| Minor (second number) | Yellow |
| Patch, revision (`_N`), or cask build (`,N`) | Default color, arrow still shown |
| Already newest, or the Homebrew version is lower | No arrow |
| Install older than 180 days | `(Nd)` in yellow |
| Install older than 365 days | `(Nd)` in red |

`openssl@3` at `3.6.4` with a formula version of `3.5.9` has no arrow. `3.5.9` is not an upgrade.

A name that already contains `@` keeps it: `python@3.14@3.14.10`.

Color is off when stdout is not a terminal, when `NO_COLOR` is set, or when `TERM` is `dumb`.

## Requirements

- Homebrew on `PATH` (`command brew`)
- bash 3.2 or newer, or zsh 5
- `awk`, `find`, and `mktemp` (standard on macOS and Linux)

`brew outdated` asks Homebrew's servers which versions exist. The installer does not use the network.

## Install

From a clone, with no copy and no edit of your shell rc:

```sh
git clone https://github.com/vmandic/bash-brewinfo.git
cd bash-brewinfo
```

zsh:

```sh
. "$PWD/share/brewinfo.zsh"
brewinfo
```

bash:

```sh
. "$PWD/share/brewinfo.bash"
brewinfo
```

Or run the command without sourcing:

```sh
./bin/brewinfo
```

To copy the files under `~/.local` and append a marked block to your shell rc, review the plan first:

```sh
./install.sh
./install.sh --write
```

`./install.sh` prints the plan and the block. It does not copy files and it does not change the rc file. `--write` does both. It backs up the rc file to a sibling `*.bak.<timestamp>` before appending. The block is wrapped in `# >>> bash-brewinfo >>>` and `# <<< bash-brewinfo <<<`.

```sh
./install.sh --uninstall
```

That removes the marked block, the copy under `~/.local/share/bash-brewinfo`, and `~/.local/bin/brewinfo` only when that symlink points at this copy. Backup files are left in place.

`--prefix` must be inside `$HOME` and must not contain `..`. `--rc` has the same limits. The script refuses to run as root and refuses to edit an rc file that is a symlink.

## Agents

Read [AGENTS.md](AGENTS.md) before installing or changing this repo. Do not pipe the installer from the network. Clone the git repository, read `install.sh`, then run it.

## Security

- Queries go through `command brew`, so a shell alias named `brew` is not used.
- Each `brew` call sets `HOMEBREW_NO_AUTO_UPDATE=1` and `HOMEBREW_NO_ENV_HINTS=1` for that call only. Your shell environment is not changed.
- Names and versions are printed only when they match `[A-Za-z0-9@._+-]` (names) or `[A-Za-z0-9._,+~-]` (versions). A line that does not match is skipped. Nothing from `brew` output is evaluated.
- The outdated list is written to a mode `600` temp file and removed when the function returns. The cleanup trap is inside a subshell, so your shell's `EXIT` trap is not replaced.
- In zsh, no variable is named `path`. zsh ties `path` to `PATH`, and a local `path` would clear the command search path.
- `install.sh` does not use the network, does not use `sudo`, and does not follow symlinks in the files it copies.

## Limits

- Cask versions are read from the Caskroom directory. `brew list --cask --versions` stops completely when one cask is missing from the current taps, so this tool does not use that command.
- Formula lines from `brew outdated --verbose` look like `name (installed) < latest`. Cask lines use `!=` instead of `<`. Both are accepted. The arrow still depends on the numeric compare, not on the sign Homebrew printed.
- The compare is not a full semver parser. The first numeric difference picks the color. A date `2026-09-25` is treated as `2026.09.25`.
- `brew outdated` can take a few seconds. If it fails, installed versions are still printed and a warning goes to stderr.
- Truecolor is used for the red. A terminal that ignores `38;2` still shows the arrow.

## Tests

Offline. No Homebrew call and no network:

```sh
./test/run.sh
```

The script runs the same cases under `/bin/bash` and `zsh -f`.

## License

[MIT](LICENSE). Copyright 2026 Vedran Mandić.
