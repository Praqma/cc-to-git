#!/usr/bin/env bash
set -u
set -e
set -o pipefail
set -o posix

[[ ${debug:-} == "true" ]] && set -x

script_dir=$(dirname $(readlink -f $0))
source $(dirname $0)/_git-functions.sh || source ./_git-functions.sh

cd $1
git_find_n_fill_empty_dirs_gitignore
