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

__update_remote() {
    local name=`get_project_config "$CURRENT_PROJECT" "name"`
    [ "$name" == "" ] && return 1

    local project_url="${1}${name}"

    git_wrapper remote set-url upstream "$project_url" 2>/dev/null
    [ $? -eq 0 ] || git_wrapper remote add upstream "$project_url"
}

__init_project() {
    ## test empty directory
    #[ "$(ls -A ./)" ] && return 1

    git_wrapper init
    [ $? -eq 0 ] || return 3

    local remote=`get_project_remote "$CURRENT_PROJECT"`
    local revision=`get_project_revision "$CURRENT_PROJECT"`

    local remote_url=`get_remote_config "$remote" "url"`
    [[ "$remote_url" == *"/" ]] || remote_url="$remote_url/"

    __update_remote "$remote_url"
    [ $? -eq 0 ] || return 2

    git_wrapper fetch upstream
    [ $? -eq 0 ] || return 4

    git_wrapper -c advice.detachedHead=false checkout "upstream/$revision"
    [ $? -eq 0 ] || return 5

    local comsg_hook_url="${remote_url%/p/}/tools/hooks/commit-msg"
    curl -Lo .git/hooks/commit-msg "${comsg_hook_url}"
    [ $? -eq 0 ] || return 6
    chmod +x .git/hooks/commit-msg
    [ $? -eq 0 ] || return 6
}

__do_sync_project() {
    local ret

    if [ -e ".git" ]; then
        std_out "${col_wt}Synching project $CURRENT_PROJECT${col_off}"

        local remote=`get_project_remote "$CURRENT_PROJECT"`
        local remote_url=`get_remote_config "$remote" "url"`
        [[ "$remote_url" == *"/" ]] || remote_url="$remote_url/"
        __update_remote "$remote_url"

        git_update
        ret=$?
    else
        std_out "${col_wt}Initialize project $CURRENT_PROJECT in $project_path${col_off}"

        __init_project
        ret=$?

        if [ $ret -eq 1 ]; then
            lerror "Cannot initialize project $CURRENT_PROJECT in $project_path: Directory not empty"
        elif [ $ret -eq 2 ]; then
            lerror "Cannot initialize project $CURRENT_PROJECT in $project_path: Invalid remote config"
        elif [ $ret -gt 2 ]; then
            lerror "Error while initializing project"
        fi
    fi

    return $ret
}

subexec_sync() {
    # initial setup
    bootstrap_repo "$@"

    # parse sub commands args
    parse_args "" "$@"

    # sync repo config
    pushd "$BASE_PATH/.repo/manifest" >/dev/null

    std_out "${col_wt}Synching manifest${col_off}"
    CURRENT_PROJECT=_repo_config_
    git_update

    popd >/dev/null

    # reload manifest
    read_repo

    # update projects
    forall_cd __do_sync_project

    return $?
}

summary_sync() {
    std_out "Synchronize all projects"
}

# kate space-indent on; indent-width 4; mixed-indent off; indent-mode cstyle;
