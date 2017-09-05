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

__do_start_feature_branch() {
    git_branch_stash_save --silent-3
    if [ $? -ne 0 -a $? -ne 3 ]; then
        return 1
    fi

    local feature_name="$1"

    local local_branch=`git_wrapper branch | grep -E "(^|\* )$feature_name\$"`

    if [ "$local_branch" == "* $feature_name" ]; then
        # already checked out
        return 0
    fi

    if [ "$2" == "--resume" ]; then
        if [ "$local_branch" == "" ]; then
            # while resuming, skip projects without the specified feature branch instead creating the branch
            lwarning "Skipping resume of ${feature_name} in project ${CURRENT_PROJECT}. Feature does not exists."
            return 1
        else
            std_out "${col_wt}Resume feature branch ${feature_name} in project $CURRENT_PROJECT${col_off}"
        fi
    else
        std_out "${col_wt}Starting new feature branch ${feature_name} in project $CURRENT_PROJECT${col_off}"
    fi

    # get remote head
    local project_rev=`get_project_revision "$CURRENT_PROJECT"`

    # create non existing branch
    if [ "$local_branch" == "" ]; then
        git_wrapper branch --no-track "$feature_name" "upstream/$project_rev"
    fi

    # checkout feature branch
    git_wrapper checkout "$feature_name"
    if [ $? -ne 0 ]; then
        lerror "Error while checking out feature branch $feature_name"
        return 1
    fi

    # restore stash if applicable
    git_branch_stash_pop --silent-3
    [ $? -ne 0 -a $? -ne 3 ] && return 1
}

subexec_start() {
    # initial setup
    bootstrap_repo "$@"

    # parse sub commands args
    parse_args "" "$@"

    # check parameter
    local feature_name="${CMD_ARGS[0]}"
    if [ "$feature_name" == "" ]; then
        lfatal "Specify a branch name"
    fi

    local _resume=
    has_opt "--resume" "$@" && _resume="--resume"

    # start feature branch in projects
    forall_cd __do_start_feature_branch "$feature_name" "$_resume"

    return $?
}

summary_start() {
    std_out "Start (create) a feature branch"
}

# kate space-indent on; indent-width 4; mixed-indent off; indent-mode cstyle;
