# brewinfo for zsh 5.
# Source this file. It defines brewinfo and does not run it.
# Read-only: it never installs, upgrades, or removes packages.

# major | minor | patch when $2 is newer than $1. same otherwise.
# A lower number is not an upgrade. _N and ,build count as a patch.
_brewinfo_bump() {
  emulate -L zsh
  setopt local_options extended_glob
  local a=$1 b=$2
  local a_rev=0 b_rev=0 a_build=0 b_build=0
  local -a A B
  local i n av bv an bn ar br

  a=${a%%+*}
  b=${b%%+*}
  if [[ $a == (#b)*_(<->) ]]; then a_rev=$match[1]; a=${a%_*}; fi
  if [[ $b == (#b)*_(<->) ]]; then b_rev=$match[1]; b=${b%_*}; fi
  case $a in *,*) a_build=${a#*,}; a=${a%%,*} ;; esac
  case $b in *,*) b_build=${b#*,}; b=${b%%,*} ;; esac
  case $a in v[0-9]*) a=${a#v} ;; esac
  case $b in v[0-9]*) b=${b#v} ;; esac
  a=${a//-/.}
  b=${b//-/.}

  A=("${(@s:.:)a}")
  B=("${(@s:.:)b}")
  n=${#A}
  (( ${#B} > n )) && n=${#B}

  for (( i = 1; i <= n; i++ )); do
    av=${A[i]-0}
    bv=${B[i]-0}
    [[ -z $av ]] && av=0
    [[ -z $bv ]] && bv=0
    an=
    bn=
    ar=
    br=
    if [[ $av == (#b)(<->)* ]]; then
      an=$((10#$match[1]))
      ar=${av#$match[1]}
    fi
    if [[ $bv == (#b)(<->)* ]]; then
      bn=$((10#$match[1]))
      br=${bv#$match[1]}
    fi
    if [[ -n $an && -n $bn ]]; then
      if (( an < bn )); then
        if (( i == 1 )); then print -r -- major
        elif (( i == 2 )); then print -r -- minor
        else print -r -- patch
        fi
        return 0
      elif (( an > bn )); then
        print -r -- same
        return 0
      fi
      if [[ $ar != $br ]]; then
        if [[ $br > $ar ]]; then
          if (( i == 1 )); then print -r -- major
          elif (( i == 2 )); then print -r -- minor
          else print -r -- patch
          fi
        else
          print -r -- same
        fi
        return 0
      fi
    elif [[ $av != $bv ]]; then
      if [[ $bv > $av ]]; then print -r -- patch
      else print -r -- same
      fi
      return 0
    fi
  done

  if [[ $a_build == <-> && $b_build == <-> ]]; then
    if (( 10#$b_build > 10#$a_build )); then print -r -- patch; return 0; fi
    if (( 10#$b_build < 10#$a_build )); then print -r -- same; return 0; fi
  elif [[ $b_build != $a_build ]]; then
    if [[ $b_build > $a_build ]]; then print -r -- patch
    else print -r -- same
    fi
    return 0
  fi

  if (( 10#$b_rev > 10#$a_rev )); then print -r -- patch; return 0; fi
  print -r -- same
}

# Prints "name<TAB>latest" or returns 1.
# Formulae use "<". Casks use "!=".
# Names and versions outside a tight set are rejected and never evaluated.
_brewinfo_parse_outdated_line() {
  emulate -L zsh
  local line=$1 name rest after latest
  case $line in
    *$'\033'*|*$'\r'*|*$'\n'*) return 1 ;;
  esac
  name=${line%% *}
  case $name in
    ''|-*) return 1 ;;
    *[!A-Za-z0-9@._+-]*) return 1 ;;
  esac
  rest=${line#* }
  [[ $rest == $line ]] && return 1
  case $rest in
    "("*") < "*|"("*") != "*) ;;
    *) return 1 ;;
  esac
  case $rest in
    *" < "*) after=${rest#*" < "} ;;
    *) after=${rest#*" != "} ;;
  esac
  latest=${after%% *}
  case $latest in
    ''|*[!A-Za-z0-9._,+~-]*) return 1 ;;
  esac
  printf '%s\t%s\n' "$name" "$latest"
}

# Prints "name<TAB>installed". The last version token is the installed one.
_brewinfo_formula_fields() {
  emulate -L zsh
  local line=$1 name rest ver
  name=${line%% *}
  case $name in
    ''|-*) return 1 ;;
    *[!A-Za-z0-9@._+-]*) return 1 ;;
  esac
  case $line in
    *" "*) ;;
    *) return 1 ;;
  esac
  rest=${line#* }
  ver=${rest##* }
  case $ver in
    ''|*[!A-Za-z0-9._,+~-]*) return 1 ;;
  esac
  printf '%s\t%s\n' "$name" "$ver"
}

_brewinfo_vlen() {
  emulate -L zsh
  setopt local_options extended_glob
  local s=$1
  s=${s//$'\e'\[[0-9;]#m/}
  print -r -- ${#s}
}

# Unix time from a Homebrew receipt. Ignores source_modified_time.
_brewinfo_json_time() {
  emulate -L zsh
  local file=$1 t
  [[ -f $file ]] || return 1
  t=$(awk '
    {
      s = $0
      while (match(s, /"time"[[:space:]]*:[[:space:]]*[0-9]+/)) {
        key = substr(s, RSTART, RLENGTH)
        pre = substr(s, 1, RSTART - 1)
        if (pre !~ /[[:alnum:]_]$/) {
          gsub(/[^0-9]/, "", key)
          print key
          exit
        }
        s = substr(s, RSTART + 1)
      }
    }
  ' "$file")
  case $t in
    ''|*[!0-9]*) return 1 ;;
  esac
  print -r -- "$t"
}

_brewinfo_json_version() {
  emulate -L zsh
  local file=$1 v
  [[ -f $file ]] || return 1
  # Only source.version. A dependency version appears earlier in the file.
  v=$(awk '
    function braces(s, ch_open, ch_shut, i, n, c) {
      n = 0
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (c == ch_open) n++
        else if (c == ch_shut) n--
      }
      return n
    }
    BEGIN { ins = 0; depth = 0 }
    !ins && /"source"[[:space:]]*:[[:space:]]*\{/ { ins = 1; depth = 0 }
    ins {
      if (match($0, /"version"[[:space:]]*:[[:space:]]*"[^"]*"/)) {
        key = substr($0, RSTART, RLENGTH)
        pre = substr($0, 1, RSTART - 1)
        if (pre !~ /[[:alnum:]_]$/) {
          sub(/^"version"[[:space:]]*:[[:space:]]*"/, "", key)
          sub(/"$/, "", key)
          print key
          exit
        }
      }
      depth += braces($0, "{", "}")
      if (depth < 0) exit
    }
  ' "$file")
  [[ -n $v ]] || return 1
  print -r -- "$v"
}

# Days since this Mac installed the version. Empty when the receipt is missing.
_brewinfo_installed_days() {
  emulate -L zsh
  local kind=$1 prefix=$2 name=$3 ver=$4 file t now days got
  case $name in ''|*..*|*/*) return 0 ;; esac
  case $ver in ''|*..*|*/*) return 0 ;; esac
  if [[ $kind == formula ]]; then
    file="$prefix/Cellar/$name/$ver/INSTALL_RECEIPT.json"
  else
    file="$prefix/Caskroom/$name/.metadata/INSTALL_RECEIPT.json"
    if [[ -f $file ]]; then
      got=$(_brewinfo_json_version "$file" || true)
      [[ -n $got && $got != $ver ]] && return 0
    fi
  fi
  t=$(_brewinfo_json_time "$file") || return 0
  now=$(date +%s)
  case $now in *[!0-9]*) return 0 ;; esac
  (( t <= now )) || return 0
  days=$(( (now - t) / 86400 ))
  print -r -- "$days"
}

# plain | minor (>180d) | major (>365d)
_brewinfo_age_class() {
  emulate -L zsh
  local days=$1
  case $days in
    ''|*[!0-9]*) print -r -- plain; return 0 ;;
  esac
  if (( days > 365 )); then
    print -r -- major
  elif (( days > 180 )); then
    print -r -- minor
  else
    print -r -- plain
  fi
}

_brewinfo_paint_age() {
  emulate -L zsh
  local days=$1 text class
  text="(${days}d)"
  class=$(_brewinfo_age_class "$days")
  case $class in
    major) print -r -- "${c_major-}${text}${c_reset-}" ;;
    minor) print -r -- "${c_minor-}${text}${c_reset-}" ;;
    *) print -r -- "$text" ;;
  esac
}

_brewinfo_fmt() {
  emulate -L zsh
  local name=$1 ver=$2 latest=$3 days=${4-}
  local text="$name@$ver" level
  case $days in
    ''|*[!0-9]*) ;;
    *) text+=" $(_brewinfo_paint_age "$days")" ;;
  esac
  if [[ -n $latest && $latest != $ver ]]; then
    level=$(_brewinfo_bump "$ver" "$latest")
    case $level in
      major) text+=" -> ${c_major-}${latest}${c_reset-}" ;;
      minor) text+=" -> ${c_minor-}${latest}${c_reset-}" ;;
      patch) text+=" -> ${latest}" ;;
    esac
  fi
  print -r -- "$text"
}

_brewinfo_lookup() {
  emulate -L zsh
  local name=$1 file=$2
  awk -F '\t' -v n="$name" '$1 == n { print $2; exit }' "$file"
}

_brewinfo_cask_ver() {
  emulate -L zsh
  local dir=$1 entry base best level
  best=
  while IFS= read -r entry; do
    [[ -z $entry ]] && continue
    base=${entry##*/}
    case $base in
      .*|*[!A-Za-z0-9._,+~-]*) continue ;;
    esac
    if [[ -z $best ]]; then
      best=$base
      continue
    fi
    level=$(_brewinfo_bump "$best" "$base")
    case $level in
      major|minor|patch) best=$base ;;
    esac
  done <<EOF
$(find "$dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
EOF
  [[ -n $best ]] && print -r -- "$best"
}

_brewinfo_columns() {
  emulate -L zsh
  setopt local_options extended_glob
  local -a items=("$@") widths colw
  local n=${#items}
  (( n == 0 )) && return 0
  local i s cols_avail try rows c r idx colw_i total best
  local line piece pad

  if [[ -n ${COLUMNS:-} && $COLUMNS == <-> && COLUMNS -ge 1 ]]; then
    cols_avail=$COLUMNS
  elif [[ -t 1 ]]; then
    cols_avail=$(tput cols 2>/dev/null || print -r -- 80)
  else
    cols_avail=80
  fi
  [[ $cols_avail == <-> ]] || cols_avail=80

  for (( i = 1; i <= n; i++ )); do
    widths[i]=$(_brewinfo_vlen "${items[i]}")
  done

  best=1
  for (( try = n; try >= 1; try-- )); do
    rows=$(( (n + try - 1) / try ))
    total=0
    for (( c = 1; c <= try; c++ )); do
      colw_i=0
      for (( r = 0; r < rows; r++ )); do
        idx=$(( r + (c - 1) * rows + 1 ))
        (( idx > n )) && break
        (( widths[idx] > colw_i )) && colw_i=${widths[idx]}
      done
      if (( colw_i == 0 )); then
        total=999999
        break
      fi
      (( c > 1 )) && total=$(( total + 2 ))
      total=$(( total + colw_i ))
    done
    if (( total <= cols_avail )); then
      best=$try
      break
    fi
  done

  rows=$(( (n + best - 1) / best ))
  for (( c = 1; c <= best; c++ )); do
    colw_i=0
    for (( r = 0; r < rows; r++ )); do
      idx=$(( r + (c - 1) * rows + 1 ))
      (( idx > n )) && break
      (( widths[idx] > colw_i )) && colw_i=${widths[idx]}
    done
    colw[c]=$colw_i
  done

  for (( r = 0; r < rows; r++ )); do
    line=
    for (( c = 1; c <= best; c++ )); do
      idx=$(( r + (c - 1) * rows + 1 ))
      (( idx > n )) && break
      piece=${items[idx]}
      if (( c < best )); then
        pad=$(( colw[c] - widths[idx] + 2 ))
        line+="${piece}$(printf '%*s' "$pad" '')"
      else
        line+=$piece
      fi
    done
    print -r -- "$line"
  done
}

_brewinfo_header() {
  emulate -L zsh
  local title=$1
  if [[ -n ${c_reset-} ]]; then
    print -r -- $'\033[1;34m==>\033[0m \033[1m'"$title"$'\033[22m'
  else
    print -r -- "==> $title"
  fi
}

brewinfo() {
  emulate -L zsh
  (
    local tmp prefix list_out out_out line parsed name ver latest days
    local -a formula_items cask_items
    # Do not name a variable "path". zsh ties path to PATH.
    local caskroom entry cask_name cask_ver
    c_major=
    c_minor=
    c_reset=
    formula_items=()
    cask_items=()

    command -v brew >/dev/null 2>&1 || {
      print -r -- 'brewinfo: brew not found' >&2
      exit 1
    }
    prefix=$(command brew --prefix 2>/dev/null) || {
      print -r -- 'brewinfo: brew --prefix failed' >&2
      exit 1
    }
    [[ -d $prefix ]] || {
      print -r -- 'brewinfo: brew prefix is not a directory' >&2
      exit 1
    }

    tmp=$(mktemp "${TMPDIR:-/tmp}/brewinfo.XXXXXX") || exit 1
    chmod 600 "$tmp" || exit 1
    trap 'rm -f "$tmp"' EXIT

    if [[ -t 1 && -z ${NO_COLOR:-} && ${TERM:-} != dumb ]]; then
      c_major=$'\033[38;2;200;16;46m'
      c_minor=$'\033[33m'
      c_reset=$'\033[0m'
    fi

    if ! list_out=$(env HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 command brew list --formula --versions 2>/dev/null); then
      print -r -- 'brewinfo: brew list failed' >&2
      exit 1
    fi
    if ! out_out=$(env HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 command brew outdated --verbose 2>/dev/null); then
      print -r -- 'brewinfo: brew outdated failed; installed versions only' >&2
      out_out=
    fi

    while IFS= read -r line; do
      [[ -z $line ]] && continue
      parsed=$(_brewinfo_parse_outdated_line "$line") || continue
      print -r -- "$parsed" >>"$tmp"
    done <<EOF
$out_out
EOF

    while IFS= read -r line; do
      [[ -z $line ]] && continue
      parsed=$(_brewinfo_formula_fields "$line") || continue
      name=${parsed%%	*}
      ver=${parsed#*	}
      latest=$(_brewinfo_lookup "$name" "$tmp")
      days=$(_brewinfo_installed_days formula "$prefix" "$name" "$ver")
      formula_items+=("$(_brewinfo_fmt "$name" "$ver" "$latest" "$days")")
    done <<EOF
$list_out
EOF

    caskroom="$prefix/Caskroom"
    if [[ -d $caskroom ]]; then
      while IFS= read -r entry; do
        [[ -z $entry ]] && continue
        [[ -d $entry ]] || continue
        [[ -L $entry ]] && continue
        cask_name=${entry##*/}
        case $cask_name in
          ''|-*) continue ;;
          *[!A-Za-z0-9@._+-]*) continue ;;
        esac
        cask_ver=$(_brewinfo_cask_ver "$entry")
        [[ -z $cask_ver ]] && continue
        latest=$(_brewinfo_lookup "$cask_name" "$tmp")
        days=$(_brewinfo_installed_days cask "$prefix" "$cask_name" "$cask_ver")
        cask_items+=("$(_brewinfo_fmt "$cask_name" "$cask_ver" "$latest" "$days")")
      done <<EOF
$(find "$caskroom" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | LC_ALL=C sort -f)
EOF
    fi

    if (( ${#formula_items} )); then
      _brewinfo_header Formulae
      _brewinfo_columns "${formula_items[@]}"
    fi
    if (( ${#cask_items} )); then
      (( ${#formula_items} )) && print
      _brewinfo_header Casks
      _brewinfo_columns "${cask_items[@]}"
    fi
  )
}
