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

__do_open_gitk() {
    std_out "${col_wt}Open gitk for ${CURRENT_PROJECT}${col_off}"

    if [ "${CMD_ARGS[parallel]}" == "1" ]; then
        git_wrapper k "$@" &
    else
        git_wrapper k "$@"
    fi

}

subexec_k() {
    # initial setup
    bootstrap_repo "$@"

    # parse sub commands args
    parse_args "p:parallel" "--allow-unknown-args" "$@"

    # update projects
    forall_cd __do_open_gitk "${UNKNOWN_CMD_ARGS[@]}"

    return $?
}

summary_k() {
    std_out "Start gitk"
}

# kate space-indent on; indent-width 4; mixed-indent off; indent-mode cstyle;
