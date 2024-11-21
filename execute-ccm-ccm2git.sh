#!/bin/bash --login 
set -e
set -u

# Load functions

[[ ${ccm_db} == "" ]] && {
  echo "ERROR: ccm_db is not set"
  exit 1
}
if [[ "${groovy_script:-}" == "" ]]; then
  echo "groovy_script must be set"
  exit 1
else
  export groovy_script=$(pwd)/${groovy_script}
  [[ -e ${groovy_script} ]] || { echo "ERROR: does not exist: $groovy_script" && exit 1; }
fi 
[[ "${git_user_name:-}" == "" ]] && { echo "ERROR: git_user_name env variable must be set. It is used for the committer and init commit author" && exit 1; }
[[ "${git_user_email:-}" == "" ]] && { echo "ERROR: git_user_email env variable must be set. It is used for the committer and init commit author" && exit 1; }
[[ "${git_email_domain:-}" == "" ]] && { echo "ERROR: git_email_domain env variable must be set. It is used for the author domain. The username part of email is retrieved from CM/Synergy" && exit 1; }
[[ "${git_server_path:-}" == "" ]] && { echo "ERROR: git_server_path env variable must be set" && exit 1; }
[[ "${jiraProjectKey:-}" == "" ]]  && { echo "ERROR: jiraProjectKey env variable must be set" && exit 1; }
#[[ "${use_cached_project_list:-}" == "" ]] && { export use_cached_project_list="true" ; }
echo "git_user_name=${git_user_name}"
echo "git_user_email=${git_user_email}"
echo "git_email_domain=${git_email_domain}"
echo "git_server_path=${git_server_path}"
echo "jiraProjectKey=${jiraProjectKey}"

if [[ "${my_workspace_root:-}" == "" ]]; then 
    echo "INFO: my_workspace_root is not set .. defaulting to $(pwd)" 
    export my_workspace_root=$(pwd)
else
    echo "INFO: my_workspace_root=${my_workspace_root}" 
fi
if [[ -e $my_workspace_root ]] ; then 
  if git -C $my_workspace_root rev-parse --git-dir 2> /dev/null ; then 
    echo "git rev-parse --git-dir show that my_workspace_root=${my_workspace_root} is inside a repo - not supported"
    echo "If you want to store it inside a Jenkins workspace then consider to checkout repo to a subdir and use \${WORKSPACE} as my_workspace_root" 
    exit 1
  else
    echo "INFO: All good .. my_workspace_root = $my_workspace_root exists, but is not inside a git repo"
  fi
fi

source "$(pwd)/${BASH_SOURCE%/*}/_ccm-start-stop-functions.sh" || source ./_ccm-start-stop-functions.sh 
ccm-start ${ccm_db}
source "$(pwd)/${BASH_SOURCE%/*}/_ccm-functions.sh" || source ./_ccm-functions.sh

[[ "${debug:-}" == "true" ]] && set -x

whoami
env > env.env

if ! which java ; then 
  if [[ ${JAVA_HOME:-} != "" ]]; then 
    export PATH="${JAVA_HOME}/bin:$PATH"
    which java || { echo "ERROR: java not found in PATH nor via $JAVA_HOME/bin" ; exit 1; }
    echo "INFO: prepending $JAVA_HOME/bin to PATH"
  else  
    echo "ERROR: java not found in PATH. Please set it in PATH or set JAVA_HOME and it is set to JAVA_HOME/bin"
    exit 1
  fi
fi
java -version

trap ccm-stop EXIT

[[ ${ccm_project_name:-} == "" ]] && { echo "ERROR: please set variable: ccm_project_name with option of <ccm_project_name>[:<instance>]" ; exit 1;  }
export ccm_project_name_wo_instance=$(echo ${ccm_project_name} | awk -F ":" '{print $1}')

export ccm_project_instance=$(echo ${ccm_project_name} | awk -F ":" '{print $2}')
if [[ ${ccm_project_instance:-} == "" ]]; then 
  if [[ ${ccm_dcm_dbid:-} != "" ]]; then 
    ccm_project_instance="${ccm_dcm_dbid}#1"
  else
    ccm_project_instance=1
  fi
fi 

export ccm_project_name_orig=""

byref_translate_from_git_repo2ccm_name $ccm_project_name_wo_instance $ccm_project_instance ccm_project_name_orig

rm -rf git2git_params.env && touch git2git_params.env
if [[ "${wipe_repo_before:-}" == "true" ]] ; then 
  echo "Execute: wipe_repo_before"
  rm -rf ${my_workspace_root}/${ccm_project_name_wo_instance}/repo 
  echo "execute_mode=reclone" >> git2git_params.env
else
  echo "INFO: wipe_repo_before is empty [''|false|true]"
fi 
if [[ "${wipe_checkout_workspace_before:-}" == "true" ]] ; then 
  echo "Execute: wipe_checkout_workspace_before"
  rm -rf ${my_workspace_root}/${ccm_project_name_wo_instance}/ccm_wa 
else
  echo "INFO: wipe_checkout_workspace_before is empty [''|false|true]"
fi

if [[ "${tag_to_be_removed:-}" != "" ]] ; then
  echo "tag_to_be_removed=${tag_to_be_removed}" >> git2git_params.env
  cd ${my_workspace_root}/${ccm_project_name_wo_instance}/repo/${ccm_project_name_wo_instance} 
  git push origin $tag_to_be_removed --delete  || echo "Deleting failed - skip"
  git push ssh://git@${git_server_path}/${ccm_project_name_wo_instance}_orig.git $tag_to_be_removed --delete  || echo "Deleting failed - skip"
  if [[ ${git_server_path_prod_ccm2git:-} != "" ]]; then
      git push origin $tag_to_be_removed --delete  || echo "Deleting failed - skip"
      git push ssh://git@${git_server_path_prod_ccm2git}/${ccm_project_name_wo_instance}_orig.git $tag_to_be_removed --delete  || echo "Deleting failed - skip"
  fi 
  git tag --delete $tag_to_be_removed
  cd ${WORKSPACE}
else
  echo "INFO: tag_to_be_removed: is not set "
fi

[[ ${ccm_proj_rev_exclusion_query:-} == "" ]] && { echo "INFO: ccm_proj_rev_exclusion_query is not set" ; }

rm -rf project_baselines.txt && touch project_baselines.txt
echo "INFO: Finding the $ccm_project_name_orig revisions that has has_no_baseline_project" 
ccm query "\
             type='project' \
         and name='${ccm_project_name_orig}' \
         and instance='${ccm_project_instance}' \
         and ( status='integrate' or status='test' or status='sqa' or status='released' ) \
         and has_no_baseline_project() ${ccm_proj_rev_exclusion_query:-}" \
         -u -f "%objectname" \
            >> project_baselines.txt || {
            exit_code=$?
            if [[ $exit_code -eq 6 ]]; then
              echo "Empty result: has_no_baseline_project - never mind"
            elif [[ $exit_code -ne 0 ]] ; then
              echo "ERROR: has_no_baseline_project something went wrong - exit : $exit_code"
              exit $exit_code
            fi
         }
         echo "" >> project_baselines.txt
echo "INFO: Finding the $ccm_project_name_orig which is is_hist_leaf" 
bash "$(pwd)/${BASH_SOURCE%/*}/ccm-baseline-history-get-root.sh" \
         "$( ccm query "\
                    type='project' \
                and name='${ccm_project_name_orig}' \
                and instance='${ccm_project_instance}' \
                and ( status='integrate' or status='test' or status='sqa' or status='released' ) \
                and is_hist_leaf() " \
                    -u -f "%objectname" | head -1 \
          )" >> project_baselines.txt   || {
            exit_code=$?
            if [[ $exit_code -eq 6 ]]; then
              echo "Empty result: is_hist_leaf - never mind"
            elif [[ $exit_code -ne 0 ]] ; then
              echo "ERROR: is_hist_leaf something went wrong - exit : $exit_code"
              exit $exit_code
            fi
         }
         echo "" >> project_baselines.txt

if [[ -f project_baselines.txt ]]; then
    ccm_project_baselines=$( sort -u < project_baselines.txt )
    export ccm_project_baselines
else
    echo "No project revision found - Neither from 'no_baseline' nor from history traverse' - exit 10"
    exit 10
fi

IFS=$'\r\n'
for ccm_project_baseline in $( sort -u < project_baselines.txt ) ; do
    
    [[ "${ccm_project_baseline}" =~ ${regex_ccm4part:?} ]] || {
      echo "4part does not comply"
      return 1
    }
    revision=${BASH_REMATCH[2]}
    
    git_repo_4part=""
    byref_translate_from_ccm_4part2git_repo_4part "${ccm_project_baseline}" git_repo_4part
   
    [[ -d ${my_workspace_root}/${ccm_project_name_wo_instance}/ccm_wa/ ]] && touch ${my_workspace_root}/${ccm_project_name_wo_instance}/ccm_wa/projects.txt
    [[ -d ${my_workspace_root}/${ccm_project_name_wo_instance}/repo/ ]] && touch ${my_workspace_root}/${ccm_project_name_wo_instance}/repo/git_sizes.txt
    
    cd ${BASH_SOURCE%/*}/
    echo "calling: java -jar build/libs/*.jar <options> in $(pwd)"
    set -x
    java -jar build/libs/*.jar \
          ${groovy_script} \
          start_project="${git_repo_4part}" \
          my_workspace_root=${my_workspace_root} \
          git_server_path=${git_server_path} \
          jiraProjectKey=${jiraProjectKey}
    [[ "${debug:-}" == "true" ]] && set -x # restore debug setting
    cd -
    cp "${my_workspace_root}/${ccm_project_name_wo_instance}/ccm_wa/projects.txt" "${my_workspace_root}/${ccm_project_name_wo_instance}/ccm_wa/projects-${revision}.txt"
    cp "${my_workspace_root}/${ccm_project_name_wo_instance}/ccm_wa/projects-${revision}.txt" "${WORKSPACE}/"
done
cat projects-*.txt | sort -u > projects.txt
for file in $(ls -1 -rt ${my_workspace_root}/${ccm_project_name_wo_instance}/repo/*@git_size.txt); do 
    size=$(cat $file | awk -F" " '{print $1}')
    echo "${size} @@@ ${file}" >> git_sizes.txt
done
ccm_amount_of_versions=$( wc -l < git_sizes.txt )
git_size=$(tail -1 git_sizes.txt | awk -F " " '{print $1}')

{
  echo "ccm_amount_of_versions=${ccm_amount_of_versions}"
  echo "git_size=${git_size}"
  echo "ccm_project_name_wo_instance=${ccm_project_name_wo_instance}"
  echo "ccm_project_instance=${ccm_project_instance}"                  
} > ccm.env
