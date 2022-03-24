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

# usage: parse_args <parameter definitions> [parameters]
#   Where "paramater definitions" (param_defs) is:
#
#     param_defs = "" | param_def (" " param_def)*
#     param_def = ( short_name ("::" type)? ) |
#                   ( short_name? ":" long_name (":" type)? )
#     short_name = [a-z]
#     long_name = [a-z][a-z0-9-]*
#     type = "r" : "o"
#
#  short_name is matched against single dash paramters. The form
#    "-abc" is allowed.
#  long_name matches against double dash paramters.
#  If type is r, the parameter must be followed by a value.
#  If type is o, the parameter can by followed by a value.
#  A value is considered any string that does not start with a dash
#
parse_args() {
    local options
    local pass_through=0
    local param
    local next
    local cnt
    local i
    local opt
    local optname
    local pos
    local found
    local args
    local argi
    local oldIFS

    options=( "$1" )
    ocnt=${#options[@]}
    shift

    if [ "$1" == "--allow-unknown-args" ]; then
        pass_through=1
        shift
    fi

    CMD_ARGS=( )
    UNKNOWN_CMD_ARGS=( )
    optname=( )
    for (( i = 0 ; i < ocnt ; i++ )); do
        oldIFS=$IFS
        IFS=":"
        opt=( ${options[$i]} )
        IFS="$oldIFS"
        if [ "${opt[1]}" == "" ]; then
            optname[$i]=${opt[0]}
        else
            optname[$i]=${opt[1]}
        fi
    done

    args=( )
    # expand "-abc" to "-a -b -c"
    while [ "$1" != "" ]; do
        param="$1"
        if [ ${#param} -gt 1 -a "${param:0:1}" == "-" -a "${param:1:1}" != "-" ]; then
            for (( i = 1 ; i < ${#param} ; i++ )); do
                args+=("-${param:$i:1}")
            done
        else
            args+=("${param}")
        fi
        shift
    done

    pos=0
    for (( argi = 0 ; argi < ${#args[@]} ; argi++ )); do
        ldebug "examining" "${args[argi]}"
        param="${args[argi]}"
        next="${args[$((argi + 1))]}"

        if [ "${param:0:1}" != "-" ]; then
            ldebug "  positional param:" "$param"
            CMD_ARGS[$pos]="$param"
            pos=$(( $pos + 1 ))
        else
            found=0
            for (( i = 0 ; i < ocnt ; i++ )); do
                oldIFS=$IFS
                IFS=":"
                opt=( ${options[$i]} )
                IFS="$oldIFS"
                ldebug "  test opt" "${optname[i]}" "-${opt[0]}" "--${opt[1]}" ":" "$param"
                if [ "-${opt[0]}" == "$param" -o "--${opt[1]}" == "$param" ]; then
                    if [ "${opt[2]}" == "r" ]; then
                        if [ "${next:0:1}" != "" -a "${next:0:1}" != "-" ]; then
                            CMD_ARGS[${optname[i]}]="$next"
                            shift
                        else
                            lfatal "Value required for parameter ${param}"
                        fi
                    elif [ "${opt[2]}" == "o" -a "${next:0:1}" != "" -a "${next:0:1}" != "-" ]; then
                        CMD_ARGS[${optname[i]}]="$next"
                        shift
                    else
                        CMD_ARGS[${optname[i]}]=1
                    fi
                    ldebug "    opt" "${optname[i]}" "=" "${CMD_ARGS[${optname[i]}]}"
                    found=1
                    break
                fi
            done
            if [ $found -eq 0 ]; then
                if [ $pass_through -eq 1 ]; then
                    UNKNOWN_CMD_ARGS+=${param}
                else
                    lfatal "Unkown parameter ${param}"
                fi
            fi
        fi
    done

    local a
    for a in "${!CMD_ARGS[@]}"; do
        ldebug "Parsed argument: ${a}=${CMD_ARGS[$a]}"
    done
}

lerror() {
    if [ $FLAG_VERBOSITY -ge 0 ]; then
        std_err "\e[1;31m[ERROR]\e[0m $@"
    fi
}

linfo() {
    if [ $FLAG_VERBOSITY -ge 1 ]; then
        std_err "\e[1;34m[INFO]\e[0m $@"
    fi
}

ldebug() {
    if [ $FLAG_VERBOSITY -ge 2 ]; then
        std_err "\e[1;35m[DEBUG]\e[0m $@"
    fi
}

ltrace() {
    if [ $FLAG_VERBOSITY -ge 3 ]; then
        std_err "\e[1;30m[TRACE]\e[0m $@"
    fi
}

lfatal() {
    local usage_callback

    if [ "${1}" == "--usage" ]; then
        usage_callback=$2
        shift
        shift
    fi

    std_err "\e[1;31m[FATAL]\e[0m $@"

    if [ "$usage_callback" != "" ]; then
        std_err ""
        std_err $($usage_callback)
    fi

    exit 1
}

show_stack_trace() {
    local l
    local i=0
    while [ 1 ]; do
        l=`caller $i`
        [ $? -ne 0 ] && break
        ltrace "#$i" "$l"
        i=$((i + 1))
    done
}

get_config() {
    git_wrapper config --file "$MANIFEST_FILE" --get "$1"
}

set_config() {
    local cfg_file="$BASE_PATH/.repo/local/$1.cfg"
    local op
    if [ "$4" == "-a" ]; then
        op="--add"
    else
        op="--replace-all"
    fi
   git_wrapper config --file "$cfg_file" "$op" "$2" "$3"
}

get_project_remote() {
    local ref=`get_config "project.$1.remote"`
    [ "$ref" != "" ] || ref=`get_config "default.remote"`
    echo "$ref"
}

get_project_revision() {
    local ref=`get_config "project.$1.revision"`
    [ "$ref" != "" ] || ref=`get_config "default.revision"`
    [ "$ref" != "" ] || ref="master"
    echo "$ref"
}

get_project_config() {
    get_config "project.$1.$2"
    return $?
}

get_remote_config() {
    get_config "remote.$1.$2"
    return $?
}

set_project_config() {
    set_config "$1" "project.$1.$2" "$3" "$4"
    return $?
}

forall() {
    local ret=0

    # TODO collect stderr for summary
    local summary=
    for CURRENT_PROJECT in "${PROJECTS[@]}"; do
        linfo "forall(): Processing project $CURRENT_PROJECT"

        reset_project_state
        "$@"
        ret=$?

        # stop on error
        if [ $ret -gt 0 -a $FLAG_IGNORE_ERRORS -eq 0 ]; then
            if [ $ret -eq 255 ]; then
                # no summary when aborting on user behave
                summary=
            fi

            break
        fi
    done

    if [ ! -z "$summary" ]; then
        echo "$summary"
    fi

    return $ret
}

forall_cd() {
    local ret=0

    for CURRENT_PROJECT in "${PROJECTS[@]}"; do
        linfo "forall_cd(): Processing project $CURRENT_PROJECT"

        reset_project_state

        # change into project path
        local project_path=`get_project_config "$CURRENT_PROJECT" "path"`
        if [ "$project_path" == "" ]; then
            lerror "Project $CURRENT_PROJECT has no path configured"
            return 1
        fi
        [ -e "$BASE_PATH/$project_path" ] || mkdir -p "$BASE_PATH/$project_path"
        pushd "$BASE_PATH/$project_path" >/dev/null

        # execute command
        "$@"
        ret=$?

        # pop directory
        popd >/dev/null

        # stop on error
        if [ $ret -gt 0 -a $FLAG_IGNORE_ERRORS -eq 0 ]; then
            break
        fi
    done

    return $ret
}

reset_project_state() {
    WORKING_DIR_STATUS=
}

ask_options() {
    local ans
    read -p "$1" -e ans
    echo ${ans,,}
}

has_opt() {
    local s="$1"
    shift
    local o
    for o in "$@"; do
        if [ "$o" == "$s" ]; then
            return 0
        fi
    done
    return 1
}

has_not_opt() {
    has_opt "$@"
    if [ $? -ne 0 ]; then
        return 0
    else
        return 1
    fi
}

# kate space-indent on; indent-width 4; mixed-indent off; indent-mode cstyle;
