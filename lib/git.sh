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

git_wrapper() {
    local cmd=
    if [ "$1" == "k" ]; then
        cmd="gitk"
        shift
    else
        cmd="git"
    fi

    ltrace "call:" "$cmd" "$@"

    "$cmd" "$@"

    return $?
}

__STASH_PREFIX="PROT-STASH: "

git_stash_save()
{
    local local_branch

    git_status
    [ $? -eq 0 ] && return 0

    local_branch=`git_wrapper symbolic-ref --short HEAD 2>/dev/null`
    if [ "$local_branch" == "" ]; then
        local_branch=`git_wrapper rev-parse HEAD 2>/dev/null`
    fi

    git_wrapper stash push -u -m "${__STASH_PREFIX}WIP on ${local_branch}"
}

git_stash_pop()
{
    local stash_info

    stash_info=`git_wrapper stash list -1 | grep "${__STASH_PREFIX}"`
    if [ "$stash_info" == "" ]; then
        return 0
    fi

    git_wrapper stash pop --index
    return $?
}

git_branch_stash_save()
{
    local head=`git_wrapper rev-parse HEAD 2>/dev/null`
    local invalid_ref=$?
    if [ $invalid_ref -ne 0 ]; then
        lerror "Checkout before do something usefull"
        return 1
    fi

    local local_branch=`git_wrapper symbolic-ref --short HEAD 2>/dev/null`
    if [ "$local_branch" == "" ]; then
        if  has_not_opt "--silent-3" "$@"; then
            lerror "Cannot stash on detached head"
        fi
        return 3
    fi

    git_status
    [ $? -eq 0 ] && return 3

    git_wrapper commit --allow-empty -m "${__STASH_PREFIX}index at $head"
    [ $? -ne 0 ] && return 2

    git_wrapper add --all
    [ $? -ne 0 ] && return 2

    git_wrapper commit --allow-empty -m "${__STASH_PREFIX}working directory at $head"
    [ $? -ne 0 ] && return 2
}

git_branch_stash_pop()
{
    git_wrapper rev-parse HEAD >/dev/null 2>&1
    local invalid_ref=$?
    if [ $invalid_ref -ne 0 ]; then
        lerror "Checkout before do something usefull"
        return 1
    fi

    local local_branch=`git_wrapper symbolic-ref --short HEAD 2>/dev/null`
    if [ "$local_branch" == "" ]; then
        local log=lerror
        has_opt "--silent-3" "$@" && ldebug
        $log "No stash to pop (detached head)"
        return 3
    fi

    local last_commit=`git_wrapper log -1 --pretty=%s | grep "^${__STASH_PREFIX} "`
    if [ "$last_commit" == "" ]; then
        local log=lerror
        has_opt "--silent-3" "$@" && ldebug
        $log "No stash to pop (missing stash)"
        return 3
    fi

    # restore unstaged changes
    git_wrapper reset --mixed HEAD^
    [ $? -ne 0 ] && return 2

    # restore staged changes
    git_wrapper reset --soft HEAD^
    [ $? -ne 0 ] && return 2
}

git_status() {
    if [ "$WORKING_DIR_STATUS" == "" -o "$1" == "--force" ]; then
        WORKING_DIR_STATUS=`git_wrapper status --porcelain`
    fi
    if [ "$WORKING_DIR_STATUS" == "" ]; then
        # clean
        return 0
    fi
    local changes=`echo "$WORKING_DIR_STATUS" | grep -v '^??'`
    if [ "$changes" == "" ]; then
        # only untracked files
        return 1
    fi
    # dirty
    return 2
}

git_shell() {
    local rcfile=`mktemp`
    cat >$rcfile <<EOF
[ -e ~/.bashrc ] && source ~/.bashrc
source "$LIB_PATH/git_helper.sh"
export PS1='git \$(__git_ps1 "(\e[0;35m%s\e[m)")> '
EOF
    bash --rcfile $rcfile </dev/tty &
    local bash_pid=$!

    while echo "`jobs -p`" | grep "$bash_pid" >/dev/null 2>&1 ; do
        wait $bash_pid 2>/dev/null
    done

    rm $rcfile
}

git_launch_gui_with_shell() {
    local gui_cmd

    if [ "$1" == "citool" ]; then
        gui_cmd="gui citool"
    else
        gui_cmd="gui"
    fi

    # run git gui async to allow to start a shell
    ( git_wrapper $gui_cmd 2>&1 >/dev/null ) &
    local gui_pid=$!

    # only launch the shell when called from a tty
    local shell_loop_pid
    if [ -t 0 ]; then
        (
            should_exit=0
            while true; do
                echo "Type 's' to enter a shell"
                while true; do
                    trap '{ stty echo; exit 255; }' SIGTERM SIGINT SIGQUIT
                    read -n 1 -s INP </dev/tty
                    trap - SIGTERM SIGINT SIGQUIT
                    if [ "$INP" == "s" -o "$INP" == "S" ]; then
                        break;
                    fi
                done

                trap "{ should_exit=1; echo -e \"\nWaiting for shell. Type 'exit' to stop.\"; }" SIGTERM

                echo "You are in the projects root directory: $PWD."
                echo "When you change files, remember to do a rescan in git gui."
                echo "Type 'exit' to exit the shell."
                git_shell

                trap - SIGTERM

                if [ $should_exit -eq 1 ]; then
                    break;
                fi
            done
        ) &
        shell_loop_pid=$!
    else
        echo "stdin is not a terminal. Cannot launch a shell."
        shell_loop_pid=
    fi

    # wait for git gui to finish
    local ret
    while echo "`jobs -p`" | grep "$gui_pid" >/dev/null 2>&1; do
        wait $gui_pid 2>/dev/null
        ret=$?
    done

    # stop shell, if any
    if [ ! -z "$shell_loop_pid" ]; then
        if echo "`jobs -p`" | grep "$shell_loop_pid" >/dev/null 2>&1; then
            kill -s TERM $shell_loop_pid 2>/dev/null
            wait $shell_loop_pid 2>/dev/null
            if [ -t 0 ]; then
                # just in case we kill the silent read
                stty echo
            fi
        fi
    fi

    # $ret is git gui's exit code
    return $ret
}

__git_conditional_launch_gui() {
    local ans=`ask_options "Start git gui? [Y(es),n(o)]? "`
    if [ "$ans" == "n" ]; then
        return 0
    fi
    git_launch_gui_with_shell
}

git_is_on_remote_head() {
    local revision=`get_project_revision "$CURRENT_PROJECT"`

    local lrev=`git_wrapper rev-parse HEAD`
    local rrev=`git_wrapper rev-parse "upstream/$revision"`
    if [ "$lref" == "$rrev" ]; then
        return 0
    fi

    return 1
}

# return code: 0:=ok, 1:=error, 2:=exit on user behalf
git_update() {
    local local_tip=`git_wrapper rev-parse HEAD 2>/dev/null`
    local invalid_ref=$?

    if [ $invalid_ref -eq 0 ]; then
        if git_is_on_remote_head; then
            # nothing to do
            return 0
        fi
    fi

    # operate on a clean working tree
    local stashed=0
    if [ $invalid_ref -eq 0 ]; then # stash only if there is something to stash on
        git_status --force
        if [ $? -ne 0 ]; then
            git_wrapper stash save -u -q
            if [ $? -ne 0 ]; then
                lerror  "Error while saving to stash"
                return 1
            fi
            stashed=1
        fi
    fi

    local revision=`get_project_revision "$CURRENT_PROJECT"`

    local old_remote_head=`git_wrapper rev-parse "upstream/$revision" 2>/dev/null`

    git_wrapper fetch "upstream"
    if [ $? -ne 0 ]; then
        lerror  "Error while fetching from remote"
        return 1
    fi

    # rebase local branch
    local local_branch
    if [ $invalid_ref -eq 0 ]; then
        local_branch=`git_wrapper symbolic-ref --short HEAD 2>/dev/null`
    else
        local_branch=
    fi

    local ans

    if [ "$local_branch" == "" ]; then
        # do we need to checkout?
        local remote_tip=`git_wrapper rev-parse "upstream/$revision"`
        # if local and remote tip are equal, there is no change remote and we
        # can leave our copy untouched
        if [ "$local_tip" != "$remote_tip" ]; then
            # simple checkout of remotes head
            git_wrapper -c advice.detachedHead=false checkout "upstream/$revision"
            if [ $? -ne 0 ]; then
                lerror "Failed to checkout remote revision"
                return 1
            fi
        fi
    else
        git_wrapper rebase --onto "upstream/$revision" "$old_remote_head" "$local_branch"
        local ret=$?
        while [ $ret -ne 0 ]; do
            lerror "Merge conflict while rebasing."
            while  [ true ]; do
                __git_conditional_launch_gui
                local stat=`git_wrapper diff --name-only -- cached`
                if [ "$stat" == "" ]; then
                    ans=`ask_options "No stages files found. Start gui again? [Y(es),n(o)]? "`
                    if [ "$ans" != "n" ]; then
                        continue
                    fi
                fi
                break
            done
            ans=`ask_options "Continue rebasing? [Y(es),s(kip this project) ,q(uit)]? "`
            if [ "$ans" == "q" ]; then
                return 255
            elif [ "$ans" == "s" ]; then
                return 0
            fi
            # else
            git_wrapper rebase --continue
            ret=$?
        done
    fi

    # restore untracked changes
    if [ $stashed -eq 1 ]; then
        git_wrapper stash pop -q
         if [ $? -ne 0 ]; then
            lerror "Error while recover from stash"
            __git_conditional_launch_gui
            ans=`ask_options "Quit update? [y(es),N(o)]? "`
            if [ "$ans" == "y" ]; then
                return 255
            fi
        fi
    fi

    return 0
}

# kate space-indent on; indent-width 4; mixed-indent off; indent-mode cstyle;
