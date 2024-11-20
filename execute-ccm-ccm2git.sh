#!/bin/bash --login 
set -e
set -u

# Load functions

source ${BASH_SOURCE%/*}/_ccm-functions.sh || source ./_ccm-functions.sh
source ${BASH_SOURCE%/*}/_ccm-start-stop-functions.sh || source ./_ccm-start-stop-functions.sh 

[[ "${debug:-}" == "true" ]] && set -x

whoami
env > env.env

which ccm
ccm-start ${ccm_db}

[[ ${ccm_project_name:-} == "" ]] && { echo "ERROR: please set variable: ccm_project_name with option of <ccm_project_name>:<instance>" ; exit 1;  }
export ccm_project_name_wo_instance=$(echo ${ccm_project_name} | awk -F ":" '{print $1}')

export ccm_project_instance=$(echo ${ccm_project_name} | awk -F ":" '{print $2}')
if [[ ${ccm_project_instance:-} == "" ]]; then 
  if [[ ${ccm_dbid:-} != "" ]]; then 
    ccm_project_instance="${ccm_dbid}#1"
  else
    ccm_project_instance=1
  fi
fi 

export ccm_project_name_orig=""

byref_translate_from_git_repo2ccm_name $ccm_project_name_wo_instance $ccm_project_instance ccm_project_name_orig

[[ "${groovy_script:-}" == "" ]]   && { echo "groovy_script must be set" && exit 1; }
[[ "${git_server_path:-}" == "" ]] && { echo "git_server_path must be set" && exit 1; }
[[ "${jiraProjectKey:-}" == "" ]]  && { echo "jiraProjectKey must be set" && exit 1; }
[[ "${use_cached_project_list:-}" == "" ]] && { export use_cached_project_list="true" ; }
[[ "${my_workspace_root:-}" == "" ]] && { export my_workspace_root=$(pwd) ; }

rm -rf git2git_params.env && touch git2git_params.env
if [[ "${wipe_repo_before:-}" == "true" ]] ; then 
  echo "Execute: wipe_repo_before"
  rm -rf ${my_workspace_root}/${ccm_project_name_wo_instance}/repo 
  echo "execute_mode=reclone" >> git2git_params.env
else
  echo "set origin URL to make sure latest configuration is maintained"
  if cd ${my_workspace_root}/${ccm_project_name_wo_instance}/repo/${ccm_project_name_wo_instance}; then 
    git remote set-url origin ssh://git@${git_server_path}/${ccm_project_name_wo_instance}.git || true 
    cd ${WORKSPACE}
  fi
fi 
if [[ "${wipe_checkout_workspace_before}" == "true" ]] ; then 
  echo "Execute: wipe_checkout_workspace_before"
  rm -rf ${my_workspace_root}/${ccm_project_name_wo_instance}/ccm_wa 
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
./ccm-baseline-history-get-root.sh \
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
    ccm status && ccm stop && ( ccm status || echo )
else
    echo "No project revision found - Neither from 'no_baseline' nor from history traverse' - exit 10"
    ccm status && ccm stop && ( ccm status || echo )
    exit 10
fi

IFS=$'\r\n'
for ccm_project_baseline in $( sort -u < project_baselines.txt ) ; do
    ccm-start "${ccm_db}"
    [[ $CCM_ADDR == "" ]] && ( echo "CM/Synergy start failed" && exit 10 )
    
    [[ "${ccm_project_baseline}" =~ ${regex_ccm4part:?} ]] || {
      echo "4part does not comply"
      return 1
    }
    revision=${BASH_REMATCH[2]}
    
    git_repo_4part=""
    byref_translate_from_ccm_4part2git_repo_4part "${ccm_project_baseline}" git_repo_4part
   
    [[ -d ${my_workspace_root}/${ccm_project_name_wo_instance}/ccm_wa/ ]] && touch ${my_workspace_root}/${ccm_project_name_wo_instance}/ccm_wa/projects.txt
    [[ -d ${my_workspace_root}/${ccm_project_name_wo_instance}/repo/ ]] && touch ${my_workspace_root}/${ccm_project_name_wo_instance}/repo/git_sizes.txt
    java -jar build/libs/*.jar \
          src/main/resources/examples/${groovy_script} \
          start_project="${git_repo_4part}" \
          my_workspace_root=${my_workspace_root} \
          git_server_path=${git_server_path} \
          jiraProjectKey=${jiraProjectKey} \
    || ( echo "Java exit with non-zero" ; ccm status ; ccm stop ; ccm status ; echo "Exit:1" && exit 1 )
    ccm status && ccm stop && ( ccm status || echo )
    mv ${my_workspace_root}/${ccm_project_name_wo_instance}/ccm_wa/projects.txt "${WORKSPACE}/projects-${revision}.txt"
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
