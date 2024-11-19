#!/usr/bin/env bash

function git_rename_annotated_tag_remote_n_locally(){
    local git_old_tag=$1
    local git_new_tag=$2

    # reset the committer to get the correct set for the commiting the tag. There is no author of the tag
    export GIT_AUTHOR_DATE=$(git tag -l --format="%(taggerdate:iso8601)" ${git_old_tag} | awk -F" " '{print $1 " " $2}') && [[ -z ${GIT_AUTHOR_DATE} ]] && return 1
    export GIT_COMMITTER_DATE=${GIT_AUTHOR_DATE}
    export GIT_COMMITTER_NAME=$(git tag -l --format="%(taggername)" ${git_old_tag} ) && [[ -z ${GIT_COMMITTER_NAME} ]] && return 1
    export GIT_COMMITTER_EMAIL=$(git tag -l --format="%(taggeremail)" ${git_old_tag} ) && [[ -z ${GIT_COMMITTER_EMAIL} ]] && return 1

    echo "Get tag content of: ${git_old_tag}"
    git tag -l --format '%(contents)' ${git_old_tag} > ./tag_meta_data.txt
    echo "git commit content of ${git_old_tag}"
    echo "git tag ${git_new_tag} based on ${git_old_tag}"
    git tag -a -F ./tag_meta_data.txt ${git_new_tag} ${git_old_tag}^{} || return 1
    rm -f ./tag_meta_data.txt
    git tag --delete ${git_old_tag} || return 1
}

function git_delete_tag_on_remote_repos(){
    local git_remote=$1
    local git_tag=$2
    git push ${git_remote} --delete ${git_tag}
}

function git_create_tag_on_remote_repos(){
    local git_remote=$1
    local git_tag=$2
    git push ${git_remote} ${git_tag}
}

function git_resolve_tags_wstatus() {
        local repo_submodule=$1
        local repo_submodule_rev=$2
        export repo_submodule_rev_wcomponent_wstatus=$(git tag | grep ${repo_submodule}/.*/${repo_submodule_rev}_rel$ || grep_exit=$? )
        # Look then for the "pub" tag
        if [[ ${repo_submodule_rev_wcomponent_wstatus} == "" ]]; then
            export repo_submodule_rev_wcomponent_wstatus=$(git tag | grep ${repo_submodule}/.*/${repo_submodule_rev}_pub$ || grep_exit=$? )
        else
            return 0
        fi
        # Accept what is there of remaining
        if [[ ${repo_submodule_rev_wcomponent_wstatus} == "" ]]; then
            export repo_submodule_rev_wcomponent_wstatus=$(git tag | grep ${repo_submodule}/.*/${repo_submodule_rev}_[dprtis][eueenq][lblsta]$ || grep_exit=$? )
        else
            return 0
        fi
}

function git_initialize_lfs_n_settings() {
    echo "Installing Git LFS for the repo"
    git lfs install
    if [[ ! $( git config --get lfs.locksverify ) ]] ; then
        git config --add --local 'lfs.locksverify' false
    fi
    if [[ ! $( git config --get lfs.contenttype ) ]] ; then
        git config --add --local lfs.contenttype 0
    fi
}

function git_set_execute_bit_in_index_of_extensions() {
    # PRE: you are in the repo
    exit_code=0
    echo "Based on file extension - set execute bit in the repo on following files:"
    git ls-files | grep -ie '.*\.exe$' -ie '.*\.sh$' -ie '.*\.pl$' || exit_code=$?
    if [[ ${exit_code} -eq 0 ]] ; then
      git ls-files | grep -ie '.*\.exe$' -ie '.*\.sh$' -ie '.*\.pl$' | xargs --no-run-if-empty -d '\n' git update-index --add --chmod=+x
      git ls-files | grep -ie '.*\.exe$' -ie '.*\.sh$' -ie '.*\.pl$' | xargs --no-run-if-empty -d '\n' chmod +x
    elif [[ ${exit_code} -eq 1 ]] ; then
      echo "No files found"
    else
      echo "ERROR occured"
      exit ${exit_code}
    fi
    echo "Done"
}

function _git_set_execute_bit(){
    echo Making ${git_ls_file} executable
    git update-index --add --chmod=+x ${git_ls_file}
    chmod +x ${git_ls_file}
}

function git_set_execute_bit_in_index_of_unix_tool_file_executable() {
    # PRE: you are in the repo
    set +x
    echo "Based on file reporting 'executable' or 'interpreter' - set execute bit in the repo on following files:"
    IFS=$'\r\n'
    for git_ls_file in `git ls-files`; do
      if file ${git_ls_file} |grep executable 2>&1 > /dev/null; then
        _git_set_execute_bit
      elif file ${git_ls_file} |grep interpreter 2>&1 > /dev/null; then
        _git_set_execute_bit
      fi
    done
    [[ ${debug:-} == "true" ]] && set -x
    echo "Done"
}

function git_find_n_fill_empty_dirs_gitignore() {
  echo "Fill empty directories with .gitignore"
  file_empty_dirs_tmp="empty_dirs.tmp"
  local exit_code=0
  /usr/bin/find . -mindepth 1 -type d -empty | grep -v '\./\.git/' > ${file_empty_dirs_tmp} || exit_code=$?
  if [[ ${exit_code} -eq 0 ]] ; then
    # grep did give an output - hence there are empty directories
    IFS=$'\r\n'
    while read empty_dir; do
      echo ${empty_dir}
      cp ${script_dir}/emptydir.gitignore ${empty_dir}/.gitignore
    done < ${file_empty_dirs_tmp} || exit 1
    unset IFS
  elif [[ ${exit_code} -eq 1 ]] ; then
    # grep did not give an output - hence there are no empty directories
    echo "INFO: no empty directories where found"
  else
    echo "ERROR occured"
    exit ${exit_code}
  fi
  rm -f ${file_empty_dirs_tmp}
  echo "Done"
}

function git_copy_tag(){
    local source_tag="$1"
    local target_tag="$2"
    local GIT_COMMITTER_NAME="$(git tag -l --format=\"%\(taggername\)\" \"$source_tag\" )"
    local GIT_COMMITTER_EMAIL="$(git tag -l --format=\"%\(taggeremail\)\" \"$source_tag\" )"
    local GIT_COMMITTER_DATE="$(git tag -l --format=\"%\(taggerdate:iso8601\)\" \"$source_tag\" )"
    git tag \
        "$target_tag" \
        "$(git tag -l --format=\"%\(*objectname\)\" \"$source_tag\" )" \
        -a \
        -m "$(git tag -l --format=\"%\(contents\)\" \$source_tag\" )"
}