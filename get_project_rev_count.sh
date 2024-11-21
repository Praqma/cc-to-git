#!/bin/bash --login 
set -e
set -u
[[ ${debug:-} == true ]] && set -x

IFS=$'\r\n'
{
    for proj in $(ccm query "type='project' and (status='integrate' or status='released') " -u -f "%name" | sort -u ) ; do 
        rev_count=$(ccm query "type='project' and name='${proj}' and ( status='released' or status='integrate' and status='test' and status='sqa')" -u -f "%objectname" | wc -l )
        printf "%s : %s\n" "$rev_count" "$proj"
    done
} | sort -rh