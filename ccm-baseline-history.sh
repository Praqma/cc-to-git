#!/bin/bash

set -euo pipefail

[[ ${debug:-} == "true" ]] && set -x


use_wildcard="" # *

# Load functions
source $(dirname $0)/_ccm-functions.sh || source ./_ccm-functions.sh

find_project_baseline_to_convert(){
    local CURRENT_PROJECT=$1
    local inherited_string_local=$2

    if [[ "${use_wildcard}" == "*" ]]; then
        proj_name=$(printf "${CURRENT_PROJECT}"  | awk -F"~|:" '{print $1}')
        proj_version=$(printf "${CURRENT_PROJECT}"  | awk -F"~|:" '{print $2}')
        proj_instance=$(printf "${CURRENT_PROJECT}"  | awk -F"~|:" '{print $4}')
        query="has_baseline_project(name match '${proj_name}*' and version='${proj_version}' and type='project' and instance='${proj_instance}') and ( status='integrate' or status='test' or status='sqa' or status='released' )"
    else
        [[ ${CURRENT_PROJECT:-} =~ ${regex_ccm4part} ]] || {
            echo "4part does not comply"
            return 1
          }
        local proj_name=${BASH_REMATCH[1]}
        local version=${BASH_REMATCH[2]}
        local type=${BASH_REMATCH[3]}
        local instance=${BASH_REMATCH[4]}

        query="has_baseline_project('${CURRENT_PROJECT}') and project='$proj_name'  and ( status='integrate' or status='test' or status='sqa' or status='released' )"
    fi

    # All status versions
    [[ ${debug:-} == "true" ]] && {
      printf "_________________________\n%s\n" "$(ccm query "${query}" -u -f "%objectname")" >&2
    }
    IFS=$'\r\n'
    for SUCCESSOR_PROJECT in $(ccm query "${query}" -u -f "%objectname") ; do
        local inherited_string="${inherited_string_local} -> ${CURRENT_PROJECT}"
        [[ ${debug:-} == "true" ]] && printf "${inherited_string}\n" >&2
        if [[ $(ccm properties -f %ccm2git_migrate "${SUCCESSOR_PROJECT}" ) == "FALSE" ]]; then
             echo "SKIP: ${SUCCESSOR_PROJECT} ccm2git_migrate=FALSE - continue" >&2
             continue # Next if already for some odd reason exists - seen in firebird~BES-SW-0906-1.8:project:2
        fi
        if [[ `grep "$SUCCESSOR_PROJECT@@@$CURRENT_PROJECT" ${projects_file}` ]]; then
             echo "ALREADY include in project file - continue" >&2
             continue # Next if already for some odd reason exists - seen in firebird~BES-SW-0906-1.8:project:2
        fi
        exit_code="0"
        find_n_set_baseline_obj_attrs_from_project "${SUCCESSOR_PROJECT}" "verbose_true" || exit_code=$?
        if [[ "${exit_code}" != "0" ]] ; then
            echo "ERROR: Project not found: ${SUCCESSOR_PROJECT}"
            exit ${exit_code}
        fi
        if [[ ${ccm_baseline_status:-} == "test_baseline-DONT_CARE" ]] ; then
            # Figure out if the project is in use as as baseline in and other project
            exit_code=0
            project_baseline_childs=$(ccm query "has_baseline_project('${SUCCESSOR_PROJECT}') and ( status='integrate' or status='test' or status='sqa' or status='released' )" -u -f "%objectname" | head -1 ) || exit_code=$?
            if [[ $exit_code -eq 6 ]]; then
              project_baseline_childs=""
            elif [[ $exit_code -ne 0 ]]; then
              echo "ERROR: something when wrong: exit code: $exit_code"
              exit $exit_code
            fi
            if [[ "${project_baseline_childs:-}" != "" ]]; then
                echo "ACCEPT: Related Baseline Object is in test status: ${SUCCESSOR_PROJECT}: ${ccm_baseline_obj_and_status_release_this} - but at least in use as baseline of project: ${project_baseline_childs}" >&2
            else
                if [[ $(ccm finduse -all_projects "$(echo ${SUCCESSOR_PROJECT} )" | grep "Object is not used in scope." ) ]]; then
                    # not in use as sub project"
                    echo "SKIP: Related Baseline Object is in test status and is NOT in use as subproject: ${SUCCESSOR_PROJECT}: ${ccm_baseline_obj_and_status_release_this} - and is leaf in project baseline history" >&2
                    continue
                else
                    # in use
                    echo "ACCEPT: Related Baseline Object is in test status and is in use as subproject: ${SUCCESSOR_PROJECT}: ${ccm_baseline_obj_and_status_release_this} - even is leaf in project baseline history" >&2
                fi
            fi
        fi
        regex_revision_contains_History='^.*\.History.*$'
        if [[ ${proj_version:-} =~ ${regex_revision_contains_History} ]] ; then
            exit_code=0
            project_baseline_childs=$(ccm query "has_baseline_project('$(echo ${SUCCESSOR_PROJECT} )') and ( status='integrate' or status='test' or status='sqa' or status='released' )" -u -f "%objectname" | head -1 ) || exit_code=$?
            if [[ $exit_code -eq 6 ]]; then
              project_baseline_childs=""
            elif [[ $exit_code -ne 0 ]]; then
              echo "ERROR: something when wrong: exit code: $exit_code"
              exit $exit_code
            fi
            if [[ "${project_baseline_childs:-}" != "" ]]; then
                echo "ACCEPT: Project revision contains 'History': ${SUCCESSOR_PROJECT}: ${ccm_baseline_obj_and_status_release_this} - but is in use as baseline of project: ${project_baseline_childs}" >&2
            else
                if [[ $(ccm finduse -all_projects "$(echo ${SUCCESSOR_PROJECT} )" | grep "Object is not used in scope." ) ]]; then
                    # not in use as sub project"
                    echo "SKIP: Project revision contains 'History and is NOT in use as subproject: ${SUCCESSOR_PROJECT}: ${ccm_baseline_obj_and_status_release_this} - even is leaf in project baseline history" >&2
                    continue
                else
                    # in use
                    echo "ACCEPT: Project revision contains '.History', but is in use as a subproject: ${SUCCESSOR_PROJECT}: ${ccm_baseline_obj_and_status_release_this} - even is leaf in project baseline history" >&2
                fi
            fi
        fi
        git_CURRENT_PROJECT=""
        byref_translate_from_ccm_4part2git_repo_4part "${CURRENT_PROJECT}" git_CURRENT_PROJECT

        git_SUCCESSOR_PROJECT=""
        byref_translate_from_ccm_4part2git_repo_4part "${SUCCESSOR_PROJECT}" git_SUCCESSOR_PROJECT
        printf "${git_SUCCESSOR_PROJECT}@@@${git_CURRENT_PROJECT}@@@${SUCCESSOR_PROJECT}@@@${CURRENT_PROJECT}\n" >> ${projects_file}
        find_project_baseline_to_convert "${SUCCESSOR_PROJECT}" "${inherited_string}"
    done
}

## MAIN ##
git_BASELINE_PROJECT="$1"

export projects_file="./projects.txt"
#rm -f ${projects_file}
if [ "${use_cached_project_list:-}X" == "trueX" ]; then
  if [ -e ${projects_file} ] ; then
    cat ${projects_file}
    exit 0
  fi
fi

ccm_BASELINE_PROJECT=""
byref_translate_from_git_repo_4part2ccm_4part "${git_BASELINE_PROJECT}" ccm_BASELINE_PROJECT


checked_version=$(ccm properties -f %version "$ccm_BASELINE_PROJECT" ) || {
  exit_code=$?
  echo "Project: $ccm_BASELINE_PROJECT does not exit - exit 1"
  exit $exit_code
}

init_project_name=$(printf "${ccm_BASELINE_PROJECT}" | awk -F"~" '{print $1}')
instance=$(printf "${ccm_BASELINE_PROJECT}" | awk -F"~|:" '{print $4}' )

inherited_string="${ccm_BASELINE_PROJECT}"
echo "$git_BASELINE_PROJECT@@@${init_project_name}~init:project:${instance}@@@$ccm_BASELINE_PROJECT@@@${init_project_name}~init:project:${instance}" > ${projects_file}

find_project_baseline_to_convert "${ccm_BASELINE_PROJECT}" "${inherited_string}"
cat ${projects_file}
