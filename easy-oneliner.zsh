#!/bin/zsh

[[ -n $ZSH_VERSION ]] || return

: ${EASY_ONE_REFFILE:="${0:A:h}/easy-oneliner.txt"}
: ${EASY_ONE_KEYBIND:="^x^x"}
: ${EASY_ONE_FILTER_COMMAND:="fzf"}
: ${EASY_ONE_FILTER_OPTS:="--reverse --no-sort --tac --ansi --exit-0"}

easy-oneliner() {
    local file
    file="$EASY_ONE_REFFILE"

    [[ ! -f $file || ! -s $file ]] && return

    local cmd q k res accept
    while accept=0; cmd="$(
        cat <"$file" \
            | sed -e '/^#/d;/^$/d' \
            | perl -pe 's/^(\[.*?\]) (.*)$/$1\t$2/' \
            | perl -pe 's/(\[.*?\])/\033[31m$1\033[m/' \
            | perl -pe 's/^(: ?)(.*)$/$1\033[30;47;1m$2\033[m/' \
            | perl -pe 's/^(.*)([[:blank:]]#[[:blank:]]?.*)$/$1\033[30;1m$2\033[m/' \
            | perl -pe 's/(!)/\033[31;1m$1\033[m/' \
            | perl -pe 's/(\|| [A-Z]+ [A-Z]+| [A-Z]+ )/\033[35;1m$1\033[m/g' \
            | ${=EASY_ONE_FILTER_COMMAND} ${=EASY_ONE_FILTER_OPTS} --query="$q"
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
        BUFFER="$(tr -d '@' <<<"$cmd" | perl -pe 's/\n/; /' | sed -e 's/; $//')"
        len="${cmd%%@*}"
        CURSOR=${#len}
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
