#!/usr/bin/env bash
#set -e
#set -x
projects_file="projects_make2.txt"
rm -f ${projects_file}.tmp && touch ${projects_file}.tmp
projects=$(ccm query "type='project' and ( name='make2' ) and ( status='integrate' or status='test' or status='sqa' or status='released' )" -u -f "%displayname@@@" | sed -e 's/ /xxx/g')
#projects="bes2~ME-ECS-SW-0905-1@@@"

for project_revision in $projects ; do
    ccm_project_name=$(echo ${project_revision} | awk -F"@@@" '{print $1}' | awk -F"~" '{print $1}')
    repo_convert_rev_tag=$(echo ${project_revision} | awk -F"@@@" '{print $1}' | awk -F"~" '{print $2}')
#    repo_baseline_rev_tag=$(echo ${project_revision} | awk -F"@@@" '{print $2}' | awk -F"~" '{print $2}')

#    if [ $(grep -c '^${ccm_project_name}~${repo_convert_rev_tag}@@@' ${projects_file}) -eq 0 ] ; then
#        echo "${ccm_project_name}~${repo_convert_rev_tag}: Found - skip.."
#        continue
#    fi

    is_baseline_of=$(ccm query "is_baseline_project_of('${ccm_project_name}~$(echo ${repo_convert_rev_tag} | sed -e 's/xxx/ /g'):project:1') and ( status='integrate' or status='test' or status='sqa' or status='released' )" -u -f "%displayname" | sed -e 's/ /xxx/g'| head -1)
    is_successor_of=$(ccm query "is_successor_of('${ccm_project_name}~$(echo ${repo_convert_rev_tag} | sed -e 's/xxx/ /g'):project:1') and ( status='integrate' or status='test' or status='sqa' or status='released' )" -u -f "%displayname" | sed -e 's/ /xxx/g' | head -1)
    has_successor=$(ccm query "has_successor('${ccm_project_name}~$(echo ${repo_convert_rev_tag} | sed -e 's/xxx/ /g'):project:1') and ( status='integrate' or status='test' or status='sqa' or status='released' )" -u -f "%displayname" | sed -e 's/ /xxx/g' | head -1)

    if [ "${is_baseline_of}X" == "X" ] ; then
        is_baseline_of="${ccm_project_name}~init"
        if [ "${is_successor_of}X" == "X" ] ; then
          is_successor_of="${ccm_project_name}~init"
        fi
#        if [ $(grep -c '^${ccm_project_name}~${repo_convert_rev_tag}' ${projects_file}.tmp) -eq 0 ] ; then
#            echo "${ccm_project_name}~${repo_convert_rev_tag}: Found - skip.."
#        else
            printf "${is_successor_of}\n"
            printf "${is_successor_of}\n"  >> ${projects_file}.tmp
#        fi
#set +x
    fi
done
