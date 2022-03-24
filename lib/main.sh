#!/bin/bash
#
# Copyright 2012-2016 by Daniel Volk <mail@volkarts.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# version
PROT_VERSION=2.1.2

# global vars
declare -A CMD_ARGS

# common functions
source "${LIBRARY_PATH}/common.sh"

# git sub commands
source "${LIBRARY_PATH}/git.sh"

initialize() {
    # init vars
    FLAG_VERBOSITY=0
    FLAG_SHOW_GLOBAL_HELP=0
    FLAG_SHOW_VERSION=0
    FLAG_IGNORE_ERRORS=0

    CMD_OPTIONS=()
    REPO_FILTER=()

    REMOTES=()
    PROJECTS=()

    # color vars
    col_off='\e[0m' # No Color
    col_wt='\e[1;37m'
    col_bk='\e[0;30m'
    col_bl='\e[0;34m'
    col_lbl='\e[1;34m'
    col_gn='\e[0;32m'
    col_lgn='\e[1;32m'
    col_cy='\e[0;36m'
    col_lcy='\e[1;36m'
    col_rd='\e[0;31m'
    col_lrd='\e[1;31m'
    col_vt='\e[0;35m'
    col_lvt='\e[1;35m'
    col_bn='\e[0;33m'
    col_yl='\e[1;33m'
    col_gy='\e[0;30m'
    col_lgy='\e[0;37m'
}

bootstrap_repo() {
    # boot strap
    init_repo
    [ $? -eq 0 ] || return 1

    read_repo
}

__parse_global_args() {
    local _opt
    for _opt in "$@"; do
        if [ "${_opt:0:1}" == "-" -a "${_opt:0:2}" != "--" ]; then
            OPTIND=0
            while getopts ":vh" flag "$_opt"; do
                case "$flag" in
                    v) FLAG_VERBOSITY=$((FLAG_VERBOSITY + 1)) ;;
                    h) FLAG_SHOW_GLOBAL_HELP=1 ;;
                    i) FLAG_IGNORE_ERRORS=1 ;;
                    ?) CMD_OPTIONS+=("$_opt") ;; # pass it to sub command
                esac
            done
        elif [ "${_opt}" == "--help" ]; then
            FLAG_SHOW_GLOBAL_HELP=1
        elif [ "${_opt}" == "--version" ]; then
            FLAG_SHOW_VERSION=1
        elif [ "${_opt:0:1}" == "@" -o -d "${_opt}" ]; then
            REPO_FILTER+=("${_opt}")
        else
            CMD_OPTIONS+=("$_opt")
        fi
    done

    return 0
}

init_repo() {
    if [ "$__CD_TO_OLDPWD_TRAP_INSTALLED" == "" ]; then
        trap "{ cd '$PWD'; }" EXIT
        __CD_TO_OLDPWD_TRAP_INSTALLED=true
    fi

    BASE_PATH=$PWD

    while [ "$BASE_PATH" != "" -a "$BASE_PATH" != "/" ]; do
        if [ -d	 "$BASE_PATH/.repo" ]; then
            CACHE_PATH="$BASE_PATH/.repo/cache"
            [ -e "$CACHE_PATH" ] || mkdir -p "$CACHE_PATH"

            [ -e "$BASE_PATH/.repo/local" ] || mkdir -p "$BASE_PATH/.repo/local"

            return 0
        fi

        BASE_PATH=`dirname "$BASE_PATH"`
    done

    lfatal "Not within a prot repository"
}

build_manifest() {
    MANIFEST_FILE="$CACHE_PATH/manifest.$$.cfg"

    if [ "$__RM_MF_TRAP_INSTALLED" == "" ]; then
        trap "{ rm -f '$MANIFEST_FILE'; }" EXIT
        __RM_MF_TRAP_INSTALLED=true
    fi

    local manifest_file_name="$BASE_PATH/.repo/manifest/manifest.cfg"

    if [ ! -f "$manifest_file_name" ]; then
        lfatal "repo does not comtain a valid manifest file"
    fi

    cat "$manifest_file_name" > "$MANIFEST_FILE"

    local f
    for f in "$BASE_PATH"/.repo/local/*.cfg; do
        [ -e "$f" ] && cat $f >> "$MANIFEST_FILE"
    done
}

read_repo() {
    local _projects
    local _project
    local _arg

    build_manifest

    PROJECTS=()
    REMOTES=`awk -F\" '/^\[remote/ { print $2 }' <"$MANIFEST_FILE"`

    _projects=`awk -F\" '/^\[project/ { print $2 }' <"$MANIFEST_FILE"`

    for _project in ${_projects[@]}; do
        [[ "$_project" == "_"*"_" ]] && continue
        if [ ${#REPO_FILTER[@]} -eq 0 ]; then
            PROJECTS+=("$_project")
        else
            for _arg in "${REPO_FILTER[@]}"; do
                if [ "${_arg:0:1}" == "@" ]; then
                    if echo $_project | grep -i ${_arg:1} >/dev/null; then
                        ldebug "Found project by name: $_project"
                        PROJECTS+=("$_project")
                    fi
                else
                    local _pp=`get_project_config "$_project" "path"`
                    _pp="${_pp#/}"
                    _pp="${_pp%/}"
                    local _fp="${_arg}"
                    if [ "$_fp" != "./" -a "$_fp" != "." ]; then
                        _fp="${_fp#./}"
                    fi
                    _fp="${_fp#/}"
                    _fp="${_fp%/}"
                    if [ "${_pp}" == "${_fp}" ]; then
                        ldebug "Found project by path: $_project"
                        PROJECTS+=("$_project")
                    fi
                fi
            done
        fi
    done
}

find_cmd() {
    if [ -e "$LIB_PATH/cmds/$1.sh" ]; then
        if [ "$2" != "--keep-cmd" ]; then
            COMMAND=$1
        fi
        source "$LIB_PATH/cmds/$1.sh"
    fi
}

__find_git_cmd() {
    local c
    for c in `git help -a | grep "^  [a-z]" | tr ' ' '\n' | grep -v "^$"`; do
        if [ "$c" == "$1" ]; then
            return 0
        fi
    done
    return 1
}

__forall_cmds() {
    local action="$1"
    local cmd
    for cmdf in `ls -1 ${LIBRARY_PATH}/cmds/*.sh 2>/dev/null`; do
        local cmd=${cmdf%.sh}
        cmd=${cmd##*/}

        source "$cmdf"
        "$action" "$cmd"
    done
}

__run_generic_git_command() {
    std_out "${col_wt}Running 'git ${1}' in project $CURRENT_PROJECT${col_off}"
    git_wrapper "$@"
}

__generic_git_command() {
    # initial setup
    bootstrap_repo "$@"

    # execute nativ git command
    forall_cd __run_generic_git_command "${@}"

    return $?
}

std_out() {
    if [ "$1" == "<" ]; then
        cat "$2"
    else
        echo -e "$@"
    fi
}

std_err() {
    if [ "$1" == "<" ]; then
        cat "$2" 1>&2
    else
        echo -e "$@" 1>&2
    fi
}

__cleanup() {
    echo $MANIFEST_FILE
    if [ "$MANIFEST_FILE" != "" -a -e "$MANIFEST_FILE" ]; then
        rm -f "$MANIFEST_FILE"
    fi
}

__show_cmd_summary() {
    printf "    %-10s %s\n" "$1" "$("summary_${1}")"
}

show_version() {
    std_out "prot version $PROT_VERSION - Copyright 2017-2022 Daniel Volk <mail@volkarts.com>"
}

show_prot_header() {
    show_version
    std_out ""
}

__global_usage() {
    show_prot_header

    std_out "Usage: $CALLER_CMD [-vh] [--help] <command> [command options...] [project paths...]"
    std_out "  Options:"
    std_out "    -v            Increase the verbosity (-v: info, -vv: debug, -vvv: trace)"
    std_out "                  default is warning"
    std_out "    -h,--help     Show this help"
    std_out "       --version  Show this help"
    std_out ""
    std_out "  <command> can be one of the following:"
    __forall_cmds "__show_cmd_summary"
    std_out ""
    std_out "  For a detailed command help type $CALLER_CMD <command> --help"
    std_out "  By specifying one or more project paths, the command is executed only for"
    std_out "  those projects."
}

exec_gprot() {
    initialize

    __parse_global_args "$@"

    if [ $FLAG_SHOW_VERSION -eq 1 ]; then
        show_version
        return 0
    fi

    find_cmd "${CMD_OPTIONS[0]}"

    if [ "$COMMAND" != "" ]; then
        if [ $FLAG_SHOW_GLOBAL_HELP -gt 0 ]; then
            # help for command requested
            help_${COMMAND}
            return 0
        else
            # run command
            CMD_OPTIONS=("${CMD_OPTIONS[@]:1}")
            subexec_${COMMAND} "${CMD_OPTIONS[@]}"
            # TODO show usage on $? -eq 100
            return $?
        fi
    else
        __find_git_cmd "${CMD_OPTIONS[0]}"
        if [ $? -eq 0 ]; then
            # pass command to git
            __generic_git_command "${CMD_OPTIONS[@]}"
            return $?
        elif [ $FLAG_SHOW_GLOBAL_HELP -gt 0 ]; then
            # show clobal help
            __global_usage
            return 0
        else
            # no such command
            if [ -z "$1" ]; then
                std_err "Specify a command"
            else
                std_err "No such command '$1'"
            fi
            return 1
        fi
    fi
}

# kate space-indent on; indent-width 4; mixed-indent off; indent-mode cstyle;
