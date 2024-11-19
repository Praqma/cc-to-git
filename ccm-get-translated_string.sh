#!/usr/bin/env bash
set -u
set -e

[[ "${debug:-}" == "true" ]] && set -x

# Load functions
source $(dirname $0)/_ccm-functions.sh || source ./_ccm-functions.sh

byref_function=$1
shift
[[ "${byref_function:-}" == "" ]]       && ( echo "'byref_function' not set as parameter 1 - exit"       && exit 1 )

result=""
case $byref_function in
  byref_translate_from_ccm_name2git_repo)
      ccm_project_name=$1
      eval $byref_function "\"${ccm_project_name}\"" result
      ;;
  *)
      eval $byref_function $@ result
      ;;
esac

printf "$result"
