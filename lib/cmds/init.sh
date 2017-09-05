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

show_init_usage() {
    echo "Usage: $(basename $0) init <URL>"
}
    
subexec_init() {
    # parse sub commands args
    parse_args \
        "b:branch:r" \
        "$@"

    local a
    for a in "${!CMD_ARGS[@]}"; do
        linfo "${a}=${CMD_ARGS[$a]}"
    done

    local url=${CMD_ARGS[0]}
    local dest=${CMD_ARGS[1]}
    local branch=${CMD_ARGS[branch]}

    [ "$url" == "" ] && lfatal --usage show_init_usage "No URL specified"

    [ "$dest" == "" ] && dest=$(pwd)

    [ "$branch" == "" ] && branch="master"

    dest="$dest/.repo/manifest"

    [ -e "$dest" ] || mkdir -p "$dest"

    (
        std_out "${col_wt}Initialize prot repository in ${dest}${col_off}"

        cd $dest

        if [ ! -e ".git" ]; then
            git_wrapper init
            [ $? -eq 0 ] || return 1
        fi

        git_wrapper remote set-url upstream $url 2>/dev/null
        [ $? -eq 0 ] || git_wrapper remote add upstream $url

        git_wrapper fetch upstream
        [ $? -eq 0 ] || return 1

        git_wrapper -c advice.detachedHead=false checkout "upstream/$branch"
        [ $? -eq 0 ] || return 1

        init_repo
        build_manifest

        local p=_repo_config_
        set_project_config "$p" "remote" "upstream"
        set_project_config "$p" "revision" "$branch"
    )
    return $?
}

summary_init() {
    std_out "Initialize a repository"
}

# kate space-indent on; indent-width 4; mixed-indent off; indent-mode cstyle;
