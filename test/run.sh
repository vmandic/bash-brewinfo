#!/bin/bash
# Offline checks for the bash 3.2 and zsh implementations.
# Does not call Homebrew and does not use the network.

set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
fail=0

check_bump() {
  local shell=$1 a=$2 b=$3 want=$4 got
  if [ "$shell" = bash ]; then
    got=$(/bin/bash --noprofile --norc -c '
      . "$1"
      _brewinfo_bump "$2" "$3"
    ' _ "$root/share/brewinfo.bash" "$a" "$b")
  else
    got=$(zsh -f -c '
      . "$1"
      _brewinfo_bump "$2" "$3"
    ' _ "$root/share/brewinfo.zsh" "$a" "$b")
  fi
  if [ "$got" != "$want" ]; then
    printf 'FAIL %s bump %s -> %s got=%s want=%s\n' "$shell" "$a" "$b" "$got" "$want" >&2
    fail=1
  fi
}

check_parse() {
  local shell=$1 line=$2 want=$3 got status
  if [ "$shell" = bash ]; then
    got=$(/bin/bash --noprofile --norc -c '
      . "$1"
      _brewinfo_parse_outdated_line "$2"
    ' _ "$root/share/brewinfo.bash" "$line") && status=0 || status=$?
  else
    got=$(zsh -f -c '
      . "$1"
      _brewinfo_parse_outdated_line "$2"
    ' _ "$root/share/brewinfo.zsh" "$line") && status=0 || status=$?
  fi
  if [ "$want" = REJECT ]; then
    if [ "$status" -eq 0 ]; then
      printf 'FAIL %s parse accepted %s\n' "$shell" "$line" >&2
      fail=1
    fi
    return 0
  fi
  if [ "$got" != "$want" ]; then
    printf 'FAIL %s parse [%s] got=[%s] want=[%s]\n' "$shell" "$line" "$got" "$want" >&2
    fail=1
  fi
}

run_shell() {
  local shell=$1
  local pair
  while IFS= read -r pair; do
    [ -z "$pair" ] && continue
    case $pair in \#*) continue ;; esac
    check_bump "$shell" "${pair%% *}" "$(printf '%s\n' "$pair" | awk '{print $2}')" "$(printf '%s\n' "$pair" | awk '{print $3}')"
  done <<'EOF'
10.0.400 11.0.100 major
3.13.3 3.15.3 minor
3.0.21 3.0.24 patch
1.6.3_1 1.6.6 patch
1.6.3_1 1.6.3_2 patch
3.6.4 3.5.9 same
9.0.5,6706 10.2.0,7022 major
1.92.2 1.147.0 minor
2026-09-25 2026-11-05 minor
2026-11-05 2026-11-12 patch
1.7.1 1.7.4 patch
4.3.2 4.5.7 minor
11.10.0 12.37.2 major
26.8.0 26.8.3 patch
3.6b 3.8 minor
1.25.0 1.25.0_2 patch
78.3 78.3_1 patch
2026.3.17_2 2026.10.26 minor
EOF

  check_parse "$shell" 'aom (3.13.3) < 3.15.3' 'aom	3.15.3'
  check_parse "$shell" 'icu4c@78 (78.3) < 78.3_1' 'icu4c@78	78.3_1'
  check_parse "$shell" 'another-redis-desktop-manager (1.7.1) != 1.7.4' 'another-redis-desktop-manager	1.7.4'
  check_parse "$shell" 'local (9.0.5,6706) != 10.2.0,7022' 'local	10.2.0,7022'
  check_parse "$shell" 'foo (1.0) < 2.0 [pinned at 1.0]' 'foo	2.0'
  check_parse "$shell" 'evil (1.0) < 2.0;touch /tmp/pwnbrew' REJECT
  check_parse "$shell" '$(touch /tmp/pwnbrew) (1.0) < 2.0' REJECT
  check_parse "$shell" 'has space (1.0) < 2.0' REJECT
}

run_shell bash
run_shell zsh

# Column order is down then across, same as brew list.
col_bash=$(COLUMNS=9 /bin/bash --noprofile --norc -c '
  . "$1"
  _brewinfo_columns aa bb cc dd
' _ "$root/share/brewinfo.bash")
col_zsh=$(COLUMNS=9 zsh -f -c '
  . "$1"
  _brewinfo_columns aa bb cc dd
' _ "$root/share/brewinfo.zsh")
want=$(printf '%s\n' 'aa  cc' 'bb  dd')
if [ "$col_bash" != "$want" ]; then
  printf 'FAIL bash columns:\n%s\n' "$col_bash" >&2
  fail=1
fi
if [ "$col_zsh" != "$want" ]; then
  printf 'FAIL zsh columns:\n%s\n' "$col_zsh" >&2
  fail=1
fi

fmt_bash=$(/bin/bash --noprofile --norc -c '
  . "$1"
  _brewinfo_fmt openssl@3 3.6.4 3.5.9
  _brewinfo_fmt ffmpeg 8.1.1 9.0.2_1
  _brewinfo_fmt aom 3.13.3 3.15.3
  _brewinfo_fmt vlc 3.0.21 3.0.24
' _ "$root/share/brewinfo.bash")
fmt_want=$(printf '%s\n' 'openssl@3@3.6.4' 'ffmpeg@8.1.1 -> 9.0.2_1' 'aom@3.13.3 -> 3.15.3' 'vlc@3.0.21 -> 3.0.24')
if [ "$fmt_bash" != "$fmt_want" ]; then
  printf 'FAIL bash fmt:\n%s\n' "$fmt_bash" >&2
  fail=1
fi

cask_tmp=$(mktemp -d "${TMPDIR:-/tmp}/brewinfo-cask.XXXXXX")
mkdir -p "$cask_tmp/1.0" "$cask_tmp/1.2" "$cask_tmp/.metadata"
ln -s "$cask_tmp/1.2" "$cask_tmp/latest"
cask_got=$(/bin/bash --noprofile --norc -c '
  . "$1"
  _brewinfo_cask_ver "$2"
' _ "$root/share/brewinfo.bash" "$cask_tmp")
rm -rf "$cask_tmp"
if [ "$cask_got" != "1.2" ]; then
  printf 'FAIL cask ver got=%s\n' "$cask_got" >&2
  fail=1
fi

age_case() {
  local shell=$1 days=$2 want=$3 got
  if [ "$shell" = bash ]; then
    got=$(/bin/bash --noprofile --norc -c '. "$1"; _brewinfo_age_class "$2"' _ "$root/share/brewinfo.bash" "$days")
  else
    got=$(zsh -f -c '. "$1"; _brewinfo_age_class "$2"' _ "$root/share/brewinfo.zsh" "$days")
  fi
  if [ "$got" != "$want" ]; then
    printf 'FAIL %s age %s got=%s want=%s\n' "$shell" "$days" "$got" "$want" >&2
    fail=1
  fi
}
for shell in bash zsh; do
  age_case "$shell" 0 plain
  age_case "$shell" 180 plain
  age_case "$shell" 181 minor
  age_case "$shell" 365 minor
  age_case "$shell" 366 major
done

receipt=$(mktemp "${TMPDIR:-/tmp}/brewinfo-receipt.XXXXXX")
cat >"$receipt" <<'EOF'
{
  "source_modified_time": 100,
  "time": 200,
  "source": { "version": "1.2.3" }
}
EOF
time_bash=$(/bin/bash --noprofile --norc -c '. "$1"; _brewinfo_json_time "$2"' _ "$root/share/brewinfo.bash" "$receipt")
ver_bash=$(/bin/bash --noprofile --norc -c '. "$1"; _brewinfo_json_version "$2"' _ "$root/share/brewinfo.bash" "$receipt")
rm -f "$receipt"
if [ "$time_bash" != 200 ] || [ "$ver_bash" != 1.2.3 ]; then
  printf 'FAIL receipt parse time=%s version=%s\n' "$time_bash" "$ver_bash" >&2
  fail=1
fi

fmt_age=$(/bin/bash --noprofile --norc -c '
  . "$1"
  _brewinfo_fmt wget 1.25.0 1.25.0_2 10
  _brewinfo_fmt ffmpeg 8.1.1 9.0 400
' _ "$root/share/brewinfo.bash")
fmt_age_want=$(printf '%s\n' 'wget@1.25.0 (10d) -> 1.25.0_2' 'ffmpeg@8.1.1 (400d) -> 9.0')
if [ "$fmt_age" != "$fmt_age_want" ]; then
  printf 'FAIL age fmt:\n%s\n' "$fmt_age" >&2
  fail=1
fi

if [ -e /tmp/pwnbrew ]; then
  printf 'FAIL hostile parse executed a command\n' >&2
  fail=1
  rm -f /tmp/pwnbrew
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi
printf '%s\n' 'ok'
