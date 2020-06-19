#!/bin/zsh

[[ -n $ZSH_VERSION ]] || return

: ${EASY_ONE_REFFILE:="${0:A:h}/easy-oneliner.txt"}
: ${EASY_ONE_KEYBIND:="^x^x"}
: ${EASY_ONE_FILTER_COMMAND:="fzf"}
: ${EASY_ONE_FILTER_OPTS:=(--reverse --no-sort --tac --ansi --exit-0)}

: ${EASY_ONE_COLOR_FILTER_COMMAND:="easy_one_liner_perl_color_filter"}
function easy_one_liner_perl_color_filter() {
  # comment out of line start with (but ignored current setting)
  perl -pe 's/^(: ?)(.*)$/$1\033[30;47;1m$2\033[m/' |
    #  set color of |
    perl -pe 's/(!)/\033[33;1m$1\033[m/' |
    # set color of 1st command
    perl -pe 's/(\]\s+)(\S+)/$1\033[32;1m$2\033[m/g' |
    # set color of 1st command(pipe)
    perl -pe 's/(\|\s+)(\S+)/$1\033[32;1m$2\033[m/g' |
    # set color  and UPPERCASE') |
    perl -pe 's/(\|| [A-Z]+ [A-Z]+| [A-Z]+ )/\033[35;1m$1\033[m/g' |
    # set color of shell $VAR
    perl -pe 's/(\$[\w]+)/\033[35;1m$1\033[m/g' |
    # set color of string ""
    perl -pe 's/([^\\])(".*[^\\]")/$1\033[33;1m$2\033[m/g' |
    # set color of single quote string
    perl -pe 's/('"'"'[^'"'"']+'"'"')/\033[35;1m$1\033[m/g' |
    # set color of \# comment
    perl -pe 's/^(.*)([[:blank:]]#[[:blank:]]?.*)$/$1\033[30;1m$2\033[m/' |
    # set color of [comment]
    perl -pe 's/(\[.*?\])/\033[36m$1\033[m/'
}
type >/dev/null 2>&1 "cgrep" && EASY_ONE_COLOR_FILTER_COMMAND="easy_one_liner_cgrep_color_filter"
function easy_one_liner_cgrep_color_filter() {
  cgrep '(.*)' 38 |
    cgrep '([^\\])(".*[^\\]")' 220 |
    # set color of string ""
    cgrep '(\$)(\().*(\))' 28,28,28 |
    # set color of shell $VAR
    cgrep '(\$[a-zA-Z_0-9]*)' |
    # set color of shell $VAR
    cgrep '(\|)' 201 |
    #  set color of |
    cgrep '(\||)|(&&)' 90,198 |
    cgrep '(;)|(\\%#)|(! *$)' 211,88,88 |
    cgrep '(^\[[^\]]*\])' 38 |
    cgrep '(\$\(|\]\t*|\| *|; *|\|\| *|&& *)([a-zA-Z_][a-zA-Z_0-9.\-]*)' ,10 |
    cgrep '('"'"'[^'"'"']+'"'"')' 226 |
    cgrep '([^\][^%]#.*$)' 250
}

cache_cat() {
  local file="$1"
  local cache_file="$HOME/.cache/easy-oneliner/$(basename $file)"
  local cache_checksum_file="$cache_file.checksum"
  mkdir -p $(dirname $cache_file)
  # NOTE: for incomplete cache file generation (e.g. kill by sigint)
  if [[ ! -f "$cache_checksum_file" ]] || ! {cat "$cache_checksum_file" | md5sum -c } >/dev/null 2>&1; then
    rm -f "$cache_file" "$cache_checksum_file"
  fi

  # NOTE: newer than
  if [[ ! -e "$cache_file" ]] || [[ "$file" -nt "$cache_file" ]]; then
    # NOTE: target file is old
    # NOTE: if input is pipe => cache
    if [[ -p /dev/stdin ]]; then
      # NOTE: you can see regenerating cache file by tee command because of pipe friendly output
      tee "$cache_file"
      md5sum "$cache_file" >"$cache_checksum_file"
      return 0
    fi
    return 1
  fi
  # NOTE: target file is latest
  cat "$cache_file"
  return 0
}

easy-oneliner() {
  local file
  file="$EASY_ONE_REFFILE"

  [[ ! -f $file || ! -s $file ]] && return

  local cmd res accept
  local fzf_extra_option
  if [[ $EASY_ONE_FILTER_COMMAND == 'fzf' ]]; then
    # CTRL-R: run command immediately
    # Enter key: normal select
    fzf_extra_option='--expect=ctrl-r'
  fi
  accept=0
  cmd="$(
    {
      cache_cat "$file" || {
        cat "$file" |
          # remove not command # comment
          sed -e '/^#/d;/^$/d' |
          # adjust [ comment ] space
          sed -E 's/^(\[[^]]*) *\](.*)$/\1@@@@]\2/g' | awk -F'@@@@' '{printf "%-22s%s\n", $1, $2;}' |
          #  add tab between [ comment ] and commands
          perl -pe 's/^(\[.*?\]) (.*)$/$1\t$2/' |
          ${EASY_ONE_COLOR_FILTER_COMMAND} | cache_cat "$file"
      }
    } | ${EASY_ONE_FILTER_COMMAND} "${EASY_ONE_FILTER_OPTS[@]}" ${fzf_extra_option}
  )"
  # remove ANSI color escapes
  res=$(echo $cmd | tail -n +2 | perl -MTerm::ANSIColor=colorstrip -ne 'print colorstrip($_)' | sed 's/[[:blank:]]#.*$//')
  if [[ -n "$res" ]]; then
    local key=$(echo $cmd | head -1)
    cmd="$(perl -pe 's/^(\[.*?\])\t(.*)$/$2/' <<<"$res")"
    if [[ $key == 'ctrl-r' || $cmd =~ "!!$" || $cmd =~ "!! *#.*$" ]]; then
      accept=2
      cmd="$(sed -e 's/!!.*$//' <<<"$cmd")"
    fi
    if [[ $cmd =~ "!$" || $cmd =~ "! *#.*$" ]]; then
      accept=1
      cmd="$(sed -e 's/!.*$//' <<<"$cmd")"
    fi
  fi

  local len
  if [[ -n $cmd ]]; then
    # NOTE: treat '\%#' as cursor position
    ret=$(sed 's/\\%#//g' <<<"$cmd" | perl -pe "chomp if eof" | perl -pe 's/\n/\\n/' | sed -e 's/; $//' | sed 's/\\%\$/\n/g')
    # NOTE: to treat '\n' as 2 chars only for cursor position
    tmp_cmd=$(perl -pe "chomp if eof" <<<"$cmd" | sed 's/\\%\$/n/g' | perl -pe 's/\n/nn/')
    len_str="${tmp_cmd%%\\%#*}"
    len=${#len_str}
    # NOTE: run immediately
    if [[ $accept -eq 2 ]]; then
      ret=$(eval "$cmd")
      len="${#ret}"
    fi
    BUFFER=${LBUFFER}${ret}${RBUFFER}
    CURSOR=$((CURSOR + $len))
    # NOTE: run at prompt
    if [[ $accept -eq 1 ]]; then
      zle accept-line
    fi
  fi

  zle redisplay
}
zle -N easy-oneliner
bindkey $EASY_ONE_KEYBIND easy-oneliner

export EASY_ONE_REFFILE
export EASY_ONE_KEYBIND
export EASY_ONE_FILTER_COMMAND
export EASY_ONE_FILTER_OPTS
