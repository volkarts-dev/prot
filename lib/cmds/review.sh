#!/bin/bash
#
# Copyright 2012-2017 by Daniel Volk <mail@volkarts.com>
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

__do_upload_for_review() {
    local local_branch=`git_wrapper symbolic-ref --short HEAD 2>/dev/null`

    if [ -z "$local_branch" ]; then
        # no feature branch checked out
        std_err "$CURRENT_PROJECT is not on any feature branch"
        return 0
    fi

    # filter by feature
    # only push if current project has checkout the requested feature branch
    if [ ! -z "$1" -a "$local_branch" != "$1" ]; then
        return 0
    fi

    std_out "${col_wt}Upload changes in $CURRENT_PROJECT for review${col_off}"

    local remote=`get_project_remote "$CURRENT_PROJECT"`

    local remote_review=`get_remote_config "$remote" "review"`
    local project_name=`get_project_config "$CURRENT_PROJECT" "name"`

    [[ "$remote_review" == *"/" ]] || remote_review="$remote_review/"
    remote_review="${remote_review}${project_name}"

    local revision=`get_project_revision "$CURRENT_PROJECT"`

    local head_id=`git_wrapper rev-parse $local_branch`
    local remote_id=`git_wrapper rev-parse upstream/$revision`

    if [ "$head_id" == "$remote_id" ]; then
        # nothing to do
        std_err "No changes to upload"
        return 0
    fi

    local tmp_file=$(mktemp)

    git_wrapper push "$remote_review" "HEAD:refs/for/$revision" 2>$tmp_file
    local ret=$?

    local error_out=$(cat "$tmp_file")
    rm "$tmp_file"

    if [ $ret -ne 0 ]; then
        if [[ "$error_out" == *"(no new changes)"* ]]; then
            std_out "No changes to upload"
            return 0
        fi
    fi

    std_err "$error_out"

    return $ret
}

subexec_review() {
    # initial setup
    bootstrap_repo "$@"

    # parse sub commands args
    parse_args "" "$@"

    # start feature branch in projects
    forall_cd __do_upload_for_review "${CMD_ARGS[0]}"

    return $?
}

summary_review() {
    std_out "Uploads the current feature branch to be reviewed"
}

help_review() {
    show_prot_header

    std_out "Usage: $CALLER_CMD review [feature branch]"
}

# kate space-indent on; indent-width 4; mixed-indent off; indent-mode cstyle;
