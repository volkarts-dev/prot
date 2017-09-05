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

__do_stop_feature_branch() {
    local local_branch=`git_wrapper symbolic-ref --short HEAD 2>/dev/null`

    if [ -z "$local_branch" ]; then
        # no feature branch checked out
        return 0
    fi

    # filter by feature
    # only stop if current project has checkout the requested feature branch
    if [ ! -z "$1" -a "$local_branch" != "$1" ]; then
        return 0
    fi

    std_out "${col_wt}Stop feature branch ${feature_name} in project $CURRENT_PROJECT${col_off}"

    git_branch_stash_save --silent-3
    if [ $? -ne 0 -a $? -ne 3 ]; then
        return 1
    fi

    # get remote head
    local project_rev=`get_project_revision "$CURRENT_PROJECT"`

    # checkout feature branch
    git_wrapper checkout "$project_rev"
    if [ $? -ne 0 ]; then
        lerror "Error while checking out remote head"
        return 1
    fi
}

subexec_start() {
    # initial setup
    bootstrap_repo "$@"

    # parse sub commands args
    parse_args "" "$@"

    # start feature branch in projects
    forall_cd __do_stop_feature_branch "${CMD_ARGS[0]}"

    return $?
}

summary_stop() {
    std_out "Stops a feature branch by checking out the upstream/HEAD"
}

help_stop() {
    show_prot_header

    std_out "Usage: $CALLER_CMD stop [feature branch]"
}

# kate space-indent on; indent-width 4; mixed-indent off; indent-mode cstyle;
