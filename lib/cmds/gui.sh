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

__do_open_gui() {
    local launch=0

    if [ "${CMD_ARGS[force]}" == "1" ]; then
        launch=2
    else
        git_status
        [ $? -ne 0 ] && launch=1
    fi

    if [ $launch -gt 0 ]; then
        if [ $launch -eq 2 ]; then
            std_out "${col_wt}Launching git gui for project $CURRENT_PROJECT${col_off}"
        else
            std_out "${col_wt}Working tree of project $CURRENT_PROJECT dirty. Launching git gui${col_off}"
        fi
        git_launch_gui_with_shell
    else
        std_out "Project $CURRENT_PROJECT: Working tree clean. Skippping."
    fi
}

subexec_gui() {
    # initial setup
    bootstrap_repo "$@"

    # parse sub commands args
    parse_args "f:force" "$@"

    # update projects
    forall_cd __do_open_gui

    return $?
}

summary_gui() {
    std_out "Start git gui"
}

# kate space-indent on; indent-width 4; mixed-indent off; indent-mode cstyle;
