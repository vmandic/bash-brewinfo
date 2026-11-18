#!/usr/bin/env bash
# Copy brewinfo under a directory in $HOME and, only with --write,
# append a marked block to one shell rc file.
# This script does not use the network and does not call sudo.

set -eu

mark_begin='# >>> bash-brewinfo >>>'
mark_end='# <<< bash-brewinfo <<<'

die() {
  printf '%s\n' "install.sh: $*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
usage: ./install.sh [--write] [--prefix DIR] [--rc FILE]
       ./install.sh --uninstall [--prefix DIR] [--rc FILE]

Default is a dry run. Nothing is copied and no rc file is changed.

--write       copy files and append the shell block
--prefix DIR  install root inside your home directory (default: ~/.local)
--rc FILE     shell rc to edit (default: from $SHELL)
--uninstall   remove the marked block, the copy, and the brewinfo link

The script refuses to run as root, refuses a prefix outside $HOME,
refuses ".." path segments, and refuses to follow a symlink rc file.
EOF
}

# Reject ".." segments. Do not resolve symlinks here: the caller checks those.
path_has_dotdot() {
  local oldifs part
  oldifs=$IFS
  IFS=/
  # shellcheck disable=SC2086
  set -f
  set -- $1
  set +f
  IFS=$oldifs
  for part in "$@"; do
    [ "$part" = ".." ] && return 0
  done
  return 1
}

abs_path() {
  local dir base
  case $1 in
    /*) printf '%s\n' "$1" ;;
    *)
      dir=$(pwd)
      printf '%s\n' "$dir/$1"
      ;;
  esac
}

inside_home() {
  case $1 in
    "$HOME"|"$HOME"/*) return 0 ;;
    *) return 1 ;;
  esac
}

default_rc() {
  case ${SHELL:-} in
    */zsh) printf '%s\n' "$HOME/.zshrc" ;;
    */bash) printf '%s\n' "$HOME/.bashrc" ;;
    *) printf '%s\n' "$HOME/.profile" ;;
  esac
}

snippet_for() {
  local dest=$1
  cat <<EOF
$mark_begin
# https://github.com/vmandic/bash-brewinfo
# Read-only Homebrew inventory. Delete this block to drop the function.
if [ -n "\${ZSH_VERSION:-}" ]; then
  . "$dest/share/brewinfo.zsh"
elif [ -n "\${BASH_VERSION:-}" ]; then
  . "$dest/share/brewinfo.bash"
fi
$mark_end
EOF
}

rc_has_mark() {
  [ -f "$1" ] && grep -F -q -e "$mark_begin" "$1"
}

backup_rc() {
  local rc=$1 stamp bak
  stamp=$(date +%Y%m%d%H%M%S)
  bak="$rc.bak.$stamp"
  cp -p "$rc" "$bak"
  printf '%s\n' "$bak"
}

append_block() {
  local rc=$1 dest=$2 mode bak
  if [ -L "$rc" ]; then
    die "$rc is a symlink. Pass a regular file with --rc."
  fi
  if [ -e "$rc" ] && [ ! -f "$rc" ]; then
    die "$rc is not a regular file."
  fi
  if rc_has_mark "$rc"; then
    printf '%s\n' "install.sh: $rc already has the bash-brewinfo block"
    return 0
  fi
  if [ -f "$rc" ]; then
    bak=$(backup_rc "$rc")
    printf '%s\n' "install.sh: backed up $rc to $bak"
    mode=$(stat -f %Lp "$rc" 2>/dev/null || stat -c %a "$rc")
  else
    mode=600
  fi
  {
    [ -f "$rc" ] && [ -s "$rc" ] && printf '\n'
    snippet_for "$dest"
    printf '\n'
  } >>"$rc"
  chmod "$mode" "$rc"
  printf '%s\n' "$rc" >"$dest/installed-rc"
  chmod 600 "$dest/installed-rc"
}

remove_block() {
  local rc=$1 tmp mode
  if [ ! -f "$rc" ]; then
    return 0
  fi
  if [ -L "$rc" ]; then
    die "$rc is a symlink. Refusing to edit it."
  fi
  if ! rc_has_mark "$rc"; then
    printf '%s\n' "install.sh: no bash-brewinfo block in $rc"
    return 0
  fi
  tmp=$(mktemp "${TMPDIR:-/tmp}/brewinfo-rc.XXXXXX")
  chmod 600 "$tmp"
  awk -v begin="$mark_begin" -v end="$mark_end" '
    $0 == begin { skip = 1; next }
    $0 == end { skip = 0; next }
    skip != 1 { print }
  ' "$rc" >"$tmp"
  mode=$(stat -f %Lp "$rc" 2>/dev/null || stat -c %a "$rc")
  chmod "$mode" "$tmp"
  mv "$tmp" "$rc"
}

copy_payload() {
  local root=$1 dest=$2
  umask 022
  mkdir -p "$dest/share" "$dest/bin"
  # -P: do not follow a symlink planted in the repo.
  cp -P "$root/share/brewinfo.bash" "$dest/share/brewinfo.bash"
  cp -P "$root/share/brewinfo.zsh" "$dest/share/brewinfo.zsh"
  cp -P "$root/bin/brewinfo" "$dest/bin/brewinfo"
  chmod 644 "$dest/share/brewinfo.bash" "$dest/share/brewinfo.zsh"
  chmod 755 "$dest/bin/brewinfo"
}

link_bin() {
  local prefix=$1 dest=$2 link
  link="$prefix/bin/brewinfo"
  mkdir -p "$prefix/bin"
  if [ -L "$link" ]; then
    if [ "$(readlink "$link")" != "$dest/bin/brewinfo" ]; then
      die "$link points elsewhere. Refusing to replace it."
    fi
  elif [ -e "$link" ]; then
    die "$link already exists and is not our symlink."
  fi
  ln -sfn "$dest/bin/brewinfo" "$link"
}

if [ "$(id -u)" -eq 0 ]; then
  die "refusing to run as root"
fi
[ -n "${HOME:-}" ] || die "HOME is not set"

write=0
uninstall=0
prefix=$HOME/.local
rc=
root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

while [ $# -gt 0 ]; do
  case $1 in
    --write) write=1 ;;
    --uninstall) uninstall=1 ;;
    --prefix)
      shift
      [ $# -gt 0 ] || die "--prefix needs a directory"
      prefix=$1
      ;;
    --rc)
      shift
      [ $# -gt 0 ] || die "--rc needs a file"
      rc=$1
      ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
  shift
done

if [ "$write" -eq 1 ] && [ "$uninstall" -eq 1 ]; then
  die "use either --write or --uninstall"
fi

prefix=$(abs_path "$prefix")
path_has_dotdot "$prefix" && die "prefix must not contain .."
inside_home "$prefix" || die "prefix must be inside $HOME"

if [ -z "$rc" ]; then
  rc=$(default_rc)
fi
rc=$(abs_path "$rc")
path_has_dotdot "$rc" && die "rc path must not contain .."
inside_home "$rc" || die "rc file must be inside $HOME"

dest=$prefix/share/bash-brewinfo

if [ "$uninstall" -eq 1 ]; then
  printf '%s\n' "install.sh: removing the marked block from $rc"
  printf '%s\n' "install.sh: removing $dest"
  printf '%s\n' "install.sh: removing $prefix/bin/brewinfo only if it points at that copy"
  remove_block "$rc"
  if [ -L "$prefix/bin/brewinfo" ] && [ "$(readlink "$prefix/bin/brewinfo")" = "$dest/bin/brewinfo" ]; then
    rm -f "$prefix/bin/brewinfo"
  fi
  if [ -d "$dest" ]; then
    rm -rf "$dest"
  fi
  printf '%s\n' "install.sh: uninstalled. Rc backups named *.bak.* were left in place."
  exit 0
fi

if [ "$write" -eq 0 ]; then
  printf '%s\n' "install.sh: dry run. No files copied. No rc file changed."
  printf '%s\n' "Would copy into $dest"
  printf '%s\n' "Would link $prefix/bin/brewinfo -> $dest/bin/brewinfo"
  printf '%s\n' "Would append a marked block to $rc (a .bak copy is made first)"
  printf '%s\n' "Run ./install.sh --write to do that."
  printf '\n'
  snippet_for "$dest"
  exit 0
fi

for need in "$root/share/brewinfo.bash" "$root/share/brewinfo.zsh" "$root/bin/brewinfo"; do
  [ -f "$need" ] || die "missing $need"
  [ -L "$need" ] && die "refusing to install from symlink $need"
done

copy_payload "$root" "$dest"
link_bin "$prefix" "$dest"
append_block "$rc" "$dest"
printf '%s\n' "install.sh: installed."
printf '%s\n' "Open a new shell, or: . \"$dest/share/brewinfo.zsh\""
case :$PATH: in
  *:"$prefix/bin":*) ;;
  *) printf '%s\n' "Add $prefix/bin to PATH if you want the brewinfo command as well as the function." ;;
esac
