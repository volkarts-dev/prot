#!/bin/bash
#
# Copyright 2012-2022 by Daniel Volk <mail@volkarts.com>
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

subexec_print_root() {
    # initial setup
    bootstrap_repo "$@"

    # run in projects
    echo "$BASE_PATH"

    return 0
}

summary_print_root() {
    std_out "Print repository's base path to stdout"
}

# kate space-indent on; indent-width 4; mixed-indent off; indent-mode cstyle;
