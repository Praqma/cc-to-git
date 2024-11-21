#!/bin/bash

[[ ${debug:-} == true ]] && set -x

[[ ${ccm_server_db_path:-} == "" ]] && {
  export ccm_server_db_path=//data/ccmdb
  echo "Setting the default data path to: ccm_server_db_path=$ccm_server_db_path"
  echo " - you can set in your bashrc or similar to overwrite"
}

[[ ${ccm_server:-} == "" ]] && {
  echo "ccm_server is not set.."
  echo " - you can set in your bashrc or export it explicitly"
  return 1
}

function check_ccm_bin_n_set_CCM_HOME() {
  echo "Checking if the 'ccm' bin is found: "
  export CCM_HOME=$(dirname $(dirname $(which ccm 2> /dev/null ))) || {
    echo "ERROR: cannot file 'ccm' in PATH"
    return 1
  }
  
}

function check_param() {
  if [[ $1 == "" ]]; then
    echo "Please set database as parameter 1"
    return 2
  fi
}

function check_user_env_var() {
  if [[ ${CCM_USER:-} != "" ]]; then
    export ccm_user_option="-n"
    echo "Setting ccm user to ${CCM_USER}"
  else
	echo "Using default user as CM/Synergy user"
  fi
}


function check_db_started_already() {
  echo "Checking if session already started"
  if [[ ${ccm_db:-} == "" && ${CCM_ADDR:-} == "" ]]; then
	echo "ccm_db and CCM_ADDR is empty - assume ok"
	return 0
  fi
  if ccm status | grep "No sessions found"; then
    return 0
  fi

  if ccm status | grep -A 1 current; then
    echo "ERROR: Already have a session running ... "
    return 3
  fi
}

function ccm-start() {
  {
    check_param $1 || return $?
    check_ccm_bin_n_set_CCM_HOME || return $?
    check_db_started_already || return $?
    check_user_env_var
    CCM_ADDR=$(ccm start ${ccm_user_option:-} ${CCM_USER:-} -m -d ${ccm_server_db_path}/${1} -s ${ccm_server} -q)
    export CCM_ADDR
  	echo "CCM_ADDR=${CCM_ADDR}"
    
    ccm_db=$1
    export ccm_db
    
    ccm_delim=$(ccm delimiter)
    export ccm_delim
    echo "ccm_delim=${ccm_delim}"
    
    ccm_dcm_dbid=$(ccm dcm -show -dbid)
    export ccm_dcm_dbid
    echo "ccm_dcm_dbid=${ccm_dcm_dbid}"

  } || { unset ccm_db ; return $?; }
}

function check_db_started_for_stop() {
  if [[ "${CCM_ADDR:-}" == "" ]]; then
    echo "CCM_ADDR is empty - exit with noop"
	unset ccm_db
    return 0
  fi
  if ccm status | grep "No sessions found"; then
    return 0
  fi
  if ccm status | grep -A 1 current; then
    return 1
  fi
}

function ccm-stop() {
  {
    ccm stop || true
    echo "unset ccm variables: CCM_HOME CCM_ADDR ccm_db ccm_delim ccm_dcm_dbid"
    unset CCM_HOME
	  unset CCM_ADDR
    unset ccm_db
    unset ccm_delim
    unset ccm_dcm_dbid
  } || return $?

}

if [[ $- == *i* ]]; then
	echo "Synergy is now setup as functions in your bash shell.."
	echo "Use:"
	echo "- ccm-start <database>"
	echo "- ccm-stop"
fi 

#ccm-start $*

set +x
