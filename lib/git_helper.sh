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

__git_ps1() {
    local head
    local gitstring

    head=`git symbolic-ref --short HEAD 2>/dev/null`
    if [ -z "${head}" ]; then
        head="Detached HEAD: `git rev-parse --short HEAD 2>/dev/null`"
    fi

    gitstring=$head

    local printf_format=' (%s)'
    if [ ! -z "$1" ]; then
        printf_format="${1:-$printf_format}"
    fi

    printf -- "$printf_format" "$gitstring"
}

# kate space-indent on; indent-width 4; mixed-indent off; indent-mode cstyle;
