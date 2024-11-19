#!/usr/bin/env bash
[[ ${debug:-} == "true" ]] && set -x
set -u
set -e
set -o pipefail

HEAD_of_tree=HEAD

for sha1 in $(git rev-list ${HEAD_of_tree} ) ; do
    tag_source=$(git tag --points-at $sha1) || { echo $sha1: null ; continue ; }
    echo $sha1: $tag_source
done
for sha1 in $( git rev-list ${HEAD_of_tree} ) ; do
    tag_source=$(git tag --points-at $sha1)
    commit_line=$(git show -s --format=@%cd@%s refs/tags/${tag_source}^{})

    sha1_of_target=$(git log --format=%H@%cd@%s origin/master | grep -e "${commit_line}" | cut -d @ -f 1 ) || { echo "ERROR: $tag_source commit is not found on origin/master" ; exit 1; }

    if [[ $(wc -w <<< ${sha1_of_target} ) -gt 1 ]]; then 
        echo "ERROR: $sha1_of_target have more than one sha1"
    fi
    printf "%s %s\n" "${tag_source}" "${sha1_of_target}"

    tag_target=${tag_source}
    tag_old_source="old/${tag_source}"

    # reset the committer to get the correct set for the commiting the tag. There is no author of the tag
    export GIT_AUTHOR_DATE=$(git tag -l --format="%(taggerdate:iso8601)" "${tag_source}" | awk -F" " '{print $1 " " $2}') && [[ -z ${GIT_AUTHOR_DATE} ]] && return 1
    export GIT_COMMITTER_DATE=${GIT_AUTHOR_DATE}
    export GIT_COMMITTER_NAME=$(git tag -l --format="%(taggername)" "${tag_source}" ) && [[ -z ${GIT_COMMITTER_NAME} ]] && return 1
    export GIT_COMMITTER_EMAIL=$(git tag -l --format="%(taggeremail)" "${tag_source}" ) && [[ -z ${GIT_COMMITTER_EMAIL} ]] && return 1

    echo "Get tag content of: ${tag_source}"
    git tag -l --format '%(contents)' "${tag_source}" > ./tag_meta_data.txt

    echo "Tag the source tag for history reasons: ${tag_source} -> ${tag_old_source}"
    git tag -a -F ./tag_meta_data.txt "${tag_old_source}" "${tag_source}^{}"
 
    echo "content of ${tag_source} to ${sha1_of_target}"
    echo "git tag ${tag_target} based on ${tag_source}"
    git tag -a -F ./tag_meta_data.txt "${tag_target}" "${sha1_of_target}" -f
    rm -f ./tag_meta_data.txt
done
