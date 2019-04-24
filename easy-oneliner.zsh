#!/bin/zsh

[[ -n $ZSH_VERSION ]] || return

: ${EASY_ONE_REFFILE:="${0:A:h}/easy-oneliner.txt"}
: ${EASY_ONE_KEYBIND:="^x^x"}
: ${EASY_ONE_FILTER_COMMAND:="fzf"}
: ${EASY_ONE_FILTER_OPTS:="--reverse --no-sort --tac --ansi --exit-0"}

: ${EASY_ONE_COLOR_FILTER_COMMAND:="easy_one_liner_perl_color_filter"}
function easy_one_liner_perl_color_filter() {
    cat \
    `: 'comment out of line start with (but ignored current setting)'` \
    | perl -pe 's/^(: ?)(.*)$/$1\033[30;47;1m$2\033[m/' \
    `: 'set color of !'` \
    | perl -pe 's/(!)/\033[33;1m$1\033[m/' \
    `: 'set color of 1st command'` \
    | perl -pe 's/(\]\s+)(\S+)/$1\033[32;1m$2\033[m/g' \
    `: 'set color of 1st command(pipe)'` \
    | perl -pe 's/(\|\s+)(\S+)/$1\033[32;1m$2\033[m/g' \
    `: 'set color of | and UPPERCASE'` \
    | perl -pe 's/(\|| [A-Z]+ [A-Z]+| [A-Z]+ )/\033[35;1m$1\033[m/g' \
    `: 'set color of shell $VAR'` \
    | perl -pe 's/(\$[\w]+)/\033[35;1m$1\033[m/g' \
    `: 'set color of string ""'` \
    | perl -pe 's/([^\\])(".*[^\\]")/$1\033[33;1m$2\033[m/g' \
    `: 'set color of single quote string'` \
    | perl -pe 's/('"'"'[^'"'"']+'"'"')/\033[35;1m$1\033[m/g' \
    `: 'set color of \# comment'` \
    | perl -pe 's/^(.*)([[:blank:]]#[[:blank:]]?.*)$/$1\033[30;1m$2\033[m/' \
    `: 'set color of [comment]'` \
    | perl -pe 's/(\[.*?\])/\033[36m$1\033[m/'
}
type >/dev/null 2>&1 "cgrep" && EASY_ONE_COLOR_FILTER_COMMAND="easy_one_liner_cgrep_color_filter"
function easy_one_liner_cgrep_color_filter() {
    cgrep '(.*)' 38 |\
    cgrep '([^\\])(".*[^\\]")' 220 |\
    cgrep '(\$)(\().*(\))' 28,28,28 |\
    cgrep '(\$[a-zA-Z_0-9]*)' |\
    cgrep '(\|)' 201 |\
    cgrep '(\||)|(&&)' 90,198 |\
    cgrep '(;)|(\\%#)|(! *$)' 211,88,88 |\
    cgrep '(^\[[^\]]*\])' 38 |\
    cgrep '(\$\(|\]\t*|\| *|; *|\|\| *|&& *)([a-zA-Z_][a-zA-Z_0-9.\-]*)' ,10 |\
    cgrep '('"'"'[^'"'"']+'"'"')' 226 |\
    cgrep '([^\][^%]#.*$)' 239
}

easy-oneliner() {
    local file
    file="$EASY_ONE_REFFILE"

    [[ ! -f $file || ! -s $file ]] && return

    local cmd res accept
    while accept=0; cmd="$(
        cat <"$file" \
            `: 'remove not command # comment'` \
            | sed -e '/^#/d;/^$/d' \
            `: 'adjust [comment] space'` \
            | sed -E 's/^(\[[^]]*) *\](.*)$/\1@@@@]\2/g' | awk -F'@@@@' '{printf "%-22s%s\n", $1, $2;}' \
            `: 'add tab between [comment] and commands'` \
            | perl -pe 's/^(\[.*?\]) (.*)$/$1\t$2/' \
            | ${=EASY_ONE_COLOR_FILTER_COMMAND} \
            | ${=EASY_ONE_FILTER_COMMAND} ${=EASY_ONE_FILTER_OPTS}
            )"; do
        # remove ANSI color escapes
        res=$(echo $cmd | perl -MTerm::ANSIColor=colorstrip -ne 'print colorstrip($_)' | sed 's/[[:blank:]]#.*$//')
        [ -z "$res" ] && continue
        cmd="$(perl -pe 's/^(\[.*?\])\t(.*)$/$2/' <<<"$res")"
        if [[ $cmd =~ "!$" || $cmd =~ "! *#.*$" ]]; then
            accept=1
            cmd="$(sed -e 's/!.*$//' <<<"$cmd")"
        fi
        break
    done

    local len
    if [[ -n $cmd ]]; then
        # NOTE: treat '\%#' as cursor position
        BUFFER=${LBUFFER}$(sed 's/\\%#//g' <<<"$cmd" | perl -pe "chomp if eof" | perl -pe 's/\n/\\n/' | sed -e 's/; $//')${RBUFFER}
        # NOTE: to treat '\n' as 2 chars
        tmp_cmd=$(perl -pe "chomp if eof" <<<"$cmd" | perl -pe 's/\n/nn/')
        len="${tmp_cmd%%\\%#*}"
        CURSOR=$((CURSOR+$#len))
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
