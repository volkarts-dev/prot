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

__do_show_status() {
    local local_branch=`git_wrapper symbolic-ref --short HEAD 2>/dev/null`

    if [ -z "$local_branch" ]; then
        # no feature branch checked out
        return 0
    fi

    std_out "${col_wt}Status of project $CURRENT_PROJECT${col_off}"

    local color
    [ -t 0 ] && color="-c color.status=1"
    git_wrapper $color status
}

subexec_status() {
    # initial setup
    bootstrap_repo "$@"

    # parse sub commands args
    parse_args "" "$@"

    local feature="${CMD_ARGS[0]}"

    # start feature branch in projects
    forall_cd __do_show_status "$feature"

    return $?
}

summary_status() {
    std_out "Shows the status of projects"
}

# kate space-indent on; indent-width 4; mixed-indent off; indent-mode cstyle;
