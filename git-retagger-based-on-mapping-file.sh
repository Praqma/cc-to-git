#!/usr/bin/env bash
set -e
set -x

#
# Rename the tags in the a repo based regex of tags
# $0 repo_dir tag_grep_regex tag_component_new full_path/tag_map_conversion_file
# $0 tardis_dev "Tardis/" "tardis_dev" `pwd`\2git\tardis_dev_release_conversion.txt
#

repo_dir=$1
tag_grep_regex=$2
tag_component_new=$3
tag_map_conversion_file=$4

cd ${repo_dir}

tags=$(git tag | grep "${tag_grep_regex}" )

for tag_orig in $tags ; do
    ccm_component_orig=$(echo $tag_orig | awk -F "/" '{print $1}')
    ccm_release_orig=$(echo $tag_orig | awk -F "/" '{print $2}')
    major_release_orig=$(echo ${ccm_release_orig} | awk -F "-" '{print $1}' )

    test "${tag_map_conversion_file}x" != "x" && test -e ${tag_map_conversion_file} && ccm_release=$(grep "${ccm_release_orig}@@@" ${tag_map_conversion_file} | awk -F "@@@" '{print $2}')
    if [ "${ccm_release}x" == "x" ]; then
        ccm_release=${ccm_release_orig}
    fi

    major_release=$(echo ${ccm_release} | awk -F "-" '{print $1}' )
    minor_release=$(echo ${ccm_release} | awk -F "-" '{print $2}' )
    build=$(echo $tag_orig | awk -F "/" '{print $3}')


    if [ "${minor_release}x" != "x" ] ; then
         tag_new="${tag_component_new}/${major_release}/${minor_release}-${build}"
    else
         # The minor is empty and assumed part of the "build"
         tag_new="${tag_component_new}/${major_release}/${build}"
    fi

    export GIT_AUTHOR_DATE=$(git tag -l --format="%(taggerdate:iso8601)" ${tag_orig} | awk -F" " '{print $1 " " $2}')
    export GIT_COMMITTER_DATE=${GIT_AUTHOR_DATE}

    git tag -l --format '%(contents)' ${tag_orig} > ./tag_meta_data.txt
    git tag -f -a -F ./tag_meta_data.txt ${tag_component_new}/${major_release}/${minor_release}-${build} ${tag_orig}

    git notes add -f -F ./tag_meta_data.txt
    rm -f ./tag_meta_data.txt

    git tag --delete ${tag_orig}

    unset GIT_AUTHOR_DATE
    unset GIT_COMMITTER_DATE
    unset ccm_release

    #sleep 1

done

