#!/usr/bin/env bash

ccm_delim=$(ccm delimiter)
regex_ccm4part="^(.+)${ccm_delim}(.+):(.+):(.+)$"

function byref_translate_from_ccm_name2git_repo() {
  if [[ -z ${1} ]]; then
    echo "${FUNCNAME[0]}: Parameter 1  - by value - cannot be empty" && exit 1
  else
    local _fromString=${1}
  fi
  if [[ -z ${2} ]]; then
    echo "${FUNCNAME[0]}: Parameter 2  - as ref - cannot be empty" && exit 1
  else
    local -n _toString=${2}
  fi
  _toString="${_fromString}"
  _toString="${_toString//ener Tam/ener-Tam}"
  _toString="${_toString// /-}"
  _toString="${_toString//&/-}"
  _toString="${_toString//#/-}"
  _toString="${_toString//(/-}"
  _toString="${_toString//)/-}"
  _toString="${_toString//ü/ue}"
  _toString="${_toString//ä/ae}"
  _toString="${_toString//æ/ae}"
  _toString="${_toString//å/aa}"
  _toString="${_toString//ö/oe}"
  _toString="${_toString//ø/oe}"
  _toString="${_toString//,/-}"
}

function byref_translate_from_git_repo2ccm_name_query() {
  if [[ -z ${1} ]]; then
    echo "${FUNCNAME[0]}: Parameter 1  - by value - cannot be empty" && exit 1
  else
    local _fromString=${1}
  fi
  if [[ -z ${2} ]]; then
    echo "${FUNCNAME[0]}: Parameter 2  - by ref - cannot be empty" && exit 1
  else
    local -n _toString=${2}
  fi
  _toString="${_fromString}"
  _toString="${_toString//ener-Tam/ener Tam}"
  _toString="${_toString//-/?}"
  _toString="${_toString//ue/??}"
  _toString="${_toString//ae/??}"
  _toString="${_toString//aa/??}"
  _toString="${_toString//oe/??}"
}

function byref_translate_from_ccm_version2git_tag() {
# https://stackoverflow.com/questions/26382234/what-names-are-valid-git-tags
#Disallowed characters: '~', '^', ':', '', '?', '[', '*'
#Disallowed sequences ".." and "@{"
#Disallowed Also tag cannot contain " " (whitespace)
  if [[ -z ${1} ]]; then
    echo "${FUNCNAME[0]}: Parameter 1  - by value - cannot be empty" && exit 1
  else
    local _fromString=${1}
  fi
  if [[ -z ${2} ]]; then
    echo "${FUNCNAME[0]}: Parameter 2  - as ref - cannot be empty" && exit 1
  else
    local -n _toString=${2}
  fi
  _toString="${_fromString// /-}"
  _toString="${_toString//&/-}"
  _toString="${_toString//#/-}"
  _toString="${_toString//(/-}"
  _toString="${_toString//)/-}"
}

function byref_translate_from_git_tag2ccm_version_query() {
  if [[ -z ${1} ]]; then
    echo "${FUNCNAME[0]}: Parameter 1  - by value - cannot be empty" && exit 1
  else
    local _fromString=${1}
  fi
  if [[ -z ${2} ]]; then
    echo "${FUNCNAME[0]}: Parameter 2  - by ref - cannot be empty" && exit 1
  else
    local -n _toString=${2}
  fi
  _toString="${_fromString//-/?}"
}


function byref_translate_from_ccm_name_instance_query2ccm_name() {
  if [[ -z ${1} ]]; then
    echo "${FUNCNAME[0]}: Parameter 1  - by value - cannot be empty" && exit 1
  else
    local _fromString=${1}
  fi
  if [[ -z ${2} ]]; then
    echo "${FUNCNAME[0]}: Parameter 2  - by value - cannot be empty" && exit 1
  else
    local _instance=${2}
  fi
  if [[ -z ${3} ]]; then
    echo "${FUNCNAME[0]}: Parameter 3  - as ref - cannot be empty" && exit 1
  else
    local -n _toString=${3}
  fi

  local _query_string="name match '$_fromString' and type='project' and instance='${_instance}'"
  local _found_project_name_instances=$(ccm query "${_query_string}" -u -f "%name:%instance" | /usr/bin/sort -u | wc -l)
  if [[ _found_project_name_instances -eq 0 ]]; then
    echo "ERROR: I found no projects with similar ? query name output  gave foo and boo "
    echo "$_query_string"
    return 1
  fi
  if [[ _found_project_name_instances -gt 1 ]]; then
    echo "ERROR: I found two or more projects with similar ? query name output -oo gave foo and boo"
    ccm query "${_query_string}" -u -f "%name:%instance"
    return 1
  fi
  _toString=$(ccm query "${_query_string}" -u -f "%name" | /usr/bin/sort -u )
}

function byref_translate_from_git_repo2ccm_name() {
  if [[ -z ${1:-} ]]; then
    echo "${FUNCNAME[0]}: Parameter 1  - by value - cannot be empty" && exit 1
  else
    local _fromString=${1}
  fi
  if [[ -z ${2:-} ]]; then
    echo "${FUNCNAME[0]}: Parameter 2  - by value - cannot be empty" && exit 1
  else
    local _instance=${2}
  fi
  if [[ -z ${3:-} ]]; then
    echo "${FUNCNAME[0]}: Parameter 3  - by ref - cannot be empty" && exit 1
  else
    local -n _toString=${3}
  fi

  local _git_repo_name=$_fromString
  local _ccm_instance=$_instance
  local _ccm_query_name=""
  byref_translate_from_git_repo2ccm_name_query "${_git_repo_name}" _ccm_query_name
  local _query_result=""
  byref_translate_from_ccm_name_instance_query2ccm_name "${_ccm_query_name}" "${_instance}" _query_result
  _toString=$_query_result
}

function byref_translate_from_git_repo_4part2ccm_4part() {
  if [[ -z ${1} ]]; then
    echo "${FUNCNAME[0]}: Parameter 1  - by value - cannot be empty" && exit 1
  else
    local _fromString=${1}
  fi
  if [[ -z ${2} ]]; then
    echo "${FUNCNAME[0]}: Parameter 2  - by ref - cannot be empty" && exit 1
  else
    local -n _toString=${2}
  fi

  [[ "${_fromString:-}" =~ ${regex_ccm4part} ]] || {
      echo "4part does not comply"
      return 1
    }
  local _name=${BASH_REMATCH[1]}
  local _version=${BASH_REMATCH[2]}
  local _type=${BASH_REMATCH[3]}
  local _instance=${BASH_REMATCH[4]}

  local _ccm_query_name=""
  byref_translate_from_git_repo2ccm_name_query "${_name}" _ccm_query_name

  local _ccm_query_version=""
  byref_translate_from_git_tag2ccm_version_query "${_version}" _ccm_query_version

  local _ccm_query_4name="$_ccm_query_name-$_ccm_query_version:$_type:$_instance"

  local _query_result=""
  byref_translate_from_ccm_4part_query2ccm_4part "${_ccm_query_4name}" _query_result
  _toString=$_query_result
}

function byref_translate_from_ccm_4part2git_repo_4part() {
  if [[ -z ${1} ]]; then
    echo "${FUNCNAME[0]}: Parameter 1  - by value - cannot be empty" && exit 1
  else
    local _fromString=${1}
  fi
  if [[ -z ${2} ]]; then
    echo "${FUNCNAME[0]}: Parameter 2  - by ref - cannot be empty" && exit 1
  else
    local -n _toString=${2}
  fi

  [[ "${_fromString:-}" =~ ${regex_ccm4part} ]] || {
      echo "4part does not comply"
      return 1
    }
  local _name=${BASH_REMATCH[1]}
  local _version=${BASH_REMATCH[2]}
  local _type=${BASH_REMATCH[3]}
  local _instance=${BASH_REMATCH[4]}

  local _git_repo=""
  byref_translate_from_ccm_name2git_repo "${_name}" _git_repo

  local _git_tag=""
  byref_translate_from_ccm_version2git_tag "${_version}" _git_tag

  _toString="${_git_repo}-${_git_tag}:$_type:$_instance"

}

function byref_translate_from_ccm_4part_query2ccm_4part() {
  if [[ -z ${1} ]]; then
    echo "Parameter 1  - as ref - cannot be empty" && return 1
  else
    local _ccm4part_query=${1}
  fi
  if [[ -z ${2} ]]; then
    echo "Parameter 2 - as ref - cannot be empty" && return 1
  else
    local -n _ccm4part=${2}
  fi

  [[ "${_ccm4part_query:-}" =~ ${regex_ccm4part} ]] || {
      echo "4part does not comply"
      return 1
    }
  local name=${BASH_REMATCH[1]}
  local version=${BASH_REMATCH[2]}
  local type=${BASH_REMATCH[3]}
  local instance=${BASH_REMATCH[4]}

  _ccm4part=$(ccm query "name match '$name' and version match '$version' and type='$type' and instance='${instance}'" -u -f "%objectname")
}

function find_n_set_baseline_obj_attrs_from_project(){
    local ccm_project_4part=$1
    local verbose="true"
    [[ ${2:-} == "verbose_false" ]] && local verbose="false"

    [[ ${ccm_project_4part} =~ ${regex_ccm4part} ]] || exit 1
    proj_name=${BASH_REMATCH[1]}
    proj_version=${BASH_REMATCH[2]}
    proj_instance=${BASH_REMATCH[4]}

    project_release=$(ccm properties -f "%release" "${ccm_project_4part}") || return $?
    if [[ "$project_release" == "<void>" ]]; then
      project_release="void"
      release_query=""
    else
      release_query=" and release='${project_release}'"
    fi

    # Find the baseline object of the project with the same release as the project itself
    ccm_baseline_obj_and_status_release_this=$(ccm query "has_project_in_baseline('${ccm_project_4part}') ${release_query}" -sby create_time -u -f "%objectname@@@%status@@@%release" | head -1 )
    regex_baseline_attr='^(.+)@@@(.+)@@@(.+)$'
    if [[ "${ccm_baseline_obj_and_status_release_this:-}" == "" ]]; then
        # No baseline found with primary release tag .. See if other baseline objects are connected ( eg. list any Baseline Object and accept the first )
        ccm_baseline_obj_and_status_release_this=$(ccm query "has_project_in_baseline('${ccm_project_4part}')" -sby create_time  -u -f "%objectname@@@%status@@@%release" | head -1 )
        if [[ "${ccm_baseline_obj_and_status_release_this:-}" == "" ]]; then
            if [[ "${verbose:-}" == "true" ]]; then
              echo "NOTE: No related Baseline Object not found at all: ${ccm_project_4part}" >&2
            fi
        else
            [[ ${ccm_baseline_obj_and_status_release_this} =~ ${regex_baseline_attr} ]] || exit 1
            ccm_baseline_obj=${BASH_REMATCH[1]}
            ccm_baseline_status=${BASH_REMATCH[2]}
            ccm_baseline_release=${BASH_REMATCH[3]}
            if [[ ${verbose:-} == "true" ]]; then
              echo "NOTE: release diff found.. ${ccm_project_4part} / ${project_release} <=> ${ccm_baseline_release} / ${ccm_baseline_obj} - accepted" >&2
            fi
        fi
    else
        [[ ${ccm_baseline_obj_and_status_release_this} =~ ${regex_baseline_attr} ]] || exit 1
        ccm_baseline_obj=${BASH_REMATCH[1]}
        ccm_baseline_status=${BASH_REMATCH[2]}
        ccm_baseline_release=${BASH_REMATCH[3]}
    fi
}

