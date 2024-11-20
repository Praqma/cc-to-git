#!/bin/bash
[[ ${debug:-} == true ]] && set -x
set -u
set -e

source $(dirname $0)/_ccm-functions.sh || source ./_ccm-functions.sh

if [[ ${1} == "" ]]; then
  printf "project parameter 1 is empty - skip" 1>&2
  exit 0
fi
BASELINE_PROJECT_tmp="$1"
BASELINE_PROJECT="$1"


printf "Processing ${BASELINE_PROJECT}\n" 1>&2

until [[ "${BASELINE_PROJECT:-}" == "" ]] ; do
	this_project4part="${BASELINE_PROJECT}"

	this_project_name=$(echo ${BASELINE_PROJECT} |  awk -F"${ccm_delim}" '{print $1}')

	query="is_baseline_project_of('${BASELINE_PROJECT}')"
	BASELINE_PROJECT=$(ccm query "is_baseline_project_of('${BASELINE_PROJECT}')" -u -f "%objectname") || BASELINE_PROJECT=""
	baseline_name=`printf "${BASELINE_PROJECT:-}" | awk -F"${ccm_delim}" '{print $1}'`
	if [[ "${baseline_name:-}" != "" && "${baseline_name}" != "${this_project_name}" ]]; then
	  printf "Stop traversing - name changed: '${this_project_name}' -> '$baseline_name'\n\n" 1>&2
	  printf "Get sucessors with '${this_project_name}' of baseline_project '${BASELINE_PROJECT}' (different name) as well\n\n" 1>&2
	  echo "${this_project4part}"
	  ccm query "has_baseline_project('${BASELINE_PROJECT}') and name='${this_project_name}' " -u -f "%objectname"
	  exit
	fi
	if [[ "${BASELINE_PROJECT:-}" != "" ]] ; then
		printf "${BASELINE_PROJECT} -> " 1>&2
	else
		printf "<void> - baseline empty\n\n" 1>&2
		break
  fi
done
project_status=$(ccm attr -show status "${this_project4part}")
case "$project_status" in
  integrate|released|sqa|test)
      printf "${this_project4part}"
      ;;
  *)
    printf "Project $this_project4part is in state: $project_status - Skip - do not list" 1>&2
    ;;
esac
