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

__do_run_shell() {
    std_out "${col_wt}Launching shell for project $CURRENT_PROJECT${col_off}"
    git_shell
    return $?
}

subexec_shell() {
    # initial setup
    bootstrap_repo "$@"

    # update projects
    forall_cd __do_run_shell

    return $?
}

summary_shell() {
    std_out "Start a shell in projects directory"
}

# kate space-indent on; indent-width 4; mixed-indent off; indent-mode cstyle;
