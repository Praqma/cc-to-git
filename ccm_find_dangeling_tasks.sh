#!/usr/bin/env bash

set -euo pipefail

[[ ${debug:-} == true ]] && set -x


#Load DB settings
source ${BASH_SOURCE%/*}/${ccm_db}_settings.sh 2> /dev/null || source ./${ccm_db}_settings.sh

if [[ ${type:-} == "task_assigned" || ${1:-} == "task_assigned" ]]; then
  query="type='task' and release match '*' and status='task_assigned'"
  time_date_field="create_time"
  subdir=task_assigned
  [[ ${jira_issue_state:-} == "" ]] && jira_issue_state="TO DO"
  echo "Running in task_assigned mode"
else
  query="type='task' and release match '*' and status='completed' and ( is_no_task_in_baseline()  ) "
  time_date_field="completion_date"
  subdir=completed
  [[ ${jira_issue_state:-} == "" ]] && jira_issue_state="IN VALIDATION"
  echo "Running in task completed mode"
fi

[[ ${objects_max:-} == "" ]] && objects_max=50

echo $query
ccm query "$query" -u -f %objectname | wc -l

mkdir -p ${subdir}
rm -rf ${subdir}/dirty.txt

function investigate_projects {
        for project in $( ccm finduse ${task_object} -all_projs | sed -e 's/\t\t//' ); do
          project_status=$(ccm attr -show status $project)
          if [[ $project_status == "integrate" || $project_status == "released" || project_status == 'sqa' || project_status == "test" ]]; then
            project_found=true
            echo "ERROR : detect conflicts for the projects due to 'folder_in_rp' can be updated after checkin"
            exit 1
            printf "OK: $task_number $project $project_status\n" >> ${subdir}/overview.txt
            printf "OK: %s : %s : %s : %s : %s : %s\n" \
                  "$task_number" \
                  "$(ccm attr -show release ${task_object})"  \
                  "$(ccm attr -show status ${task_object})" \
                  "$(ccm attr -show resolver ${task_object})" \
                  "$(ccm attr -show ${time_date_field} ${task_object})" \
                  "$(ccm attr -show task_synopsis ${task_object})" >> ${subdir}/overview.txt

            ccm finduse ${task_object} -all_projs >> ${subdir}/in_static_project/$task
            return
          fi
      done
}

#yyyy-MM-dd HH:mm:ss

IFS=$'\r\n'
for task_number_resolver in $(ccm query "$query" -u -f "%task_number@%resolver" ) ; do
    task_number=${task_number_resolver%@*}
    task_resolver=${task_number_resolver#*@}
    temp_dir_path=${subdir}/_${task_number}-${task_resolver}
    final_dir_path=${subdir}/${task_number}-${task_resolver}

    if [[ -d ${final_dir_path} ]]; then
      printf "|"
      continue
    else
      printf '\n'
    fi
    rm -rf ${temp_dir_path}
    rm -f ${temp_dir_path}/*.commit ${temp_dir_path}/*.csv

    task_object=$(ccm query "task('$task_number')" -u -f %objectname)


    baseline_found=false
 #   sleep 1
    printf "${task_number}: "
    for baseline in $(ccm query "has_dirty_task_in_baseline('${task_object}') or has_task_in_baseline('${task_object}') " || true ) ; do
      baseline_found=true
      [[ ${details:-} == true ]] && echo $baseline
    done

    if [[ ${baseline_found:-} == false ]] ; then
      project_found=false
      #investigate_projects
      if [[ ${project_found} == false ]]; then
        object_count="$(ccm query "is_associated_cv_of('$task_object') and not (type='dir' or type='project')" -u -f "%objectname" | wc -l)" || exit_code=$?
        if [[ $object_count -eq 0 ]]; then
          printf " $object_count  - skip"
          continue
        fi
        mkdir -p ${temp_dir_path}
        printf " $object_count "
        printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n" \
                  "\"${task_number}\"" \
                  "\"${jira_issue_type}\"" \
                  "\"${jira_issue_state}\"" \
                  "\"${jira_issue_epic_state:-New}\"" \
                  "\"$(ccm attr -show release ${task_object})\""  \
                  "\"${task_resolver}\"" \
                  "\"${task_resolver}\"" \
                  "\"$(ccm attr -show ${time_date_field} ${task_object})\"" \
                  "\"$(ccm attr -show ${time_date_field} ${task_object})\"" \
                  "\"${object_count}\"" \
                  "\"${task_number}-dangTask [ccmTask]: $(ccm attr -show task_synopsis ${task_object})\"" \
                  "\"${task_number}-dangTask [ccmTask]: $(ccm attr -show task_synopsis ${task_object})\"" \
                  "\"Details: ${details_link}/${final_dir_path}\"" \
                  "\"${subdir}\"" > ${temp_dir_path}/task_info_${task_number}.csv
        printf "%s-%s : %s\n" \
                  "${jira_project_key}" \
                  "${task_number}" \
                  "${task_number}-dangTask [ccmTask]: $(ccm attr -show task_synopsis ${task_object})" \
                   > ${temp_dir_path}/${task_number}.commit
        ccm task -show info -v $task_number > ${temp_dir_path}/task_info_${task_number}.txt
        if [[ ${folders:-} == true ]]; then
          folders_found=false
          {
            printf "\n\nFolders:\n"
            for folder in $( ccm finduse ${task_object} -all_folders | grep -A 100 Folder | sed -e 's/\t\t//' ); do
              folders_found=true
            done
            echo
          } >> ${temp_dir_path}/task_info_${task_number}.txt
        fi
        if [[ ${objects:-} == true ]]; then
          echo >> ${temp_dir_path}/task_info_${task_number}.txt
          printf "\n\nObjects and predecessors:\n" >> ${temp_dir_path}/task_info_${task_number}.txt

          if [[ $object_count -gt ${objects_max} ]]; then
            printf "over 50 objects - skipped"
            echo " - over 50 objects: $object_count - skipped" >> ${temp_dir_path}/task_info_${task_number}.txt
          else
            for object in $(ccm query "is_associated_cv_of('$task_object') and not (type='dir' or type='project')" -u -f "%objectname" ); do
              echo "+ $object" >> ${temp_dir_path}/task_info_${task_number}.txt
              ccm finduse -all_projs $object >> ${temp_dir_path}/task_info_${task_number}.txt
              ccm query "has_successor('${object}')" -u -f " - predecessor: %objectname" >> ${temp_dir_path}/task_info_${task_number}.txt || {
                exit_code=$?
                [[ $exit_code != 6 ]] && { echo "ERROR: something is not right in predecessor of $task_number - $object"; exit $exit_code ; }
              }
              if [[ -e ${temp_dir_path}/${object} ]]; then
                printf "."
              else
                printf ","
                ccm cat $object > ${temp_dir_path}/_${object}
                mv ${temp_dir_path}/_${object} ${temp_dir_path}/${object}
              fi
            done
          fi
          echo >> ${temp_dir_path}/task_info_${task_number}.txt
        fi
        mv ${temp_dir_path}  ${final_dir_path}
      fi
    else
      printf "WARNING: likely dirty"
      printf "%s - skip - likely dirty\n" "$task_number" >> ${subdir}/dirty.txt
    fi
done
echo

echo "Collection csv for Jira"
echo "Issue id ,Issue Type ,Status, Epic Status, FixVersion,Assignee,Reporter,Date created,Date modified,CCM Objects, Summary,Epic Name,Description,Labels"  > ${subdir}/all.csv

find ${subdir} -name task_info_*.csv  | xargs -I % cat % >> ${subdir}/all.csv
ls -la ${subdir}/all.csv

echo "Collecting commit messages"
printf "${subdir}: Task information and objects\n\n" > ${subdir}/all.commit
find ${subdir} -name [[:digit:]]*.commit | xargs -I % cat % >> ${subdir}/all.commit
ls -la ${subdir}/all.commit
echo