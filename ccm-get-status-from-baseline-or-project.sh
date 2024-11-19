#!/usr/bin/env bash
set -u
set -e

[[ "${debug:-}" == "true" ]] && set -x

# Load functions
source $(dirname $0)/_ccm-functions.sh || source ./_ccm-functions.sh

ccm_proj_obj_string="$1"

exit_code="0"
find_n_set_baseline_obj_attrs_from_project "${ccm_proj_obj_string}" "verbose_false" || exit_code=$?
if [[ "${exit_code}" != "0" ]] ; then
    echo "ERROR: Project not found: ${ccm_proj_obj_string}"
    exit ${exit_code}
fi

if [[ "${ccm_baseline_status:-}" == "" ]]; then
    # We could not set status from baseline object - take it from the project
    ccm_baseline_status=$(ccm attr -show status "${ccm_proj_obj_string}" |  sed -e 's/ //g' |  cut -c1-3)
else
    ccm_baseline_status=$(echo ${ccm_baseline_status} |  cut -c1-3)
fi
if [[ "${ccm_baseline_status:-}" == "" ]] ; then
    echo "Something went wrong as no status is set"
    exit 1
else
    echo ${ccm_baseline_status}
fi