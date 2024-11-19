#!/usr/bin/env bash

# Load functions
source ./_ccm-functions.sh || source ${BASH_SOURCE%/*}/_ccm-functions.sh

[[ "${debug:-}" == "true" ]] && set -x


set -euo pipefail

ccm_project_name="Create NG_shared_MPC55xx_dev_ser"
expected_result="Create-NG_shared_MPC55xx_dev_ser"
result=""
printf "%-8s: %-80s : %-75s " "test" "byref_translate_from_ccm_name2git_repo" "${ccm_project_name} -> $expected_result"
byref_translate_from_ccm_name2git_repo "$ccm_project_name" result
[[ "$result" == "${expected_result}" ]] && { printf "%10s\n" "SUCCESS" ; }|| { printf " FAILED: ${expected_result} != $result\n" ;}

ccm_project_name="Create-NG_shared_MPC55xx_dev_ser"
expected_result="Create?NG_shared_MPC55xx_dev_ser"
result=""
printf "%-8s: %-80s : %-75s " "test" "byref_translate_from_git_repo2ccm_name_query" "${ccm_project_name} -> $expected_result"
byref_translate_from_git_repo2ccm_name_query $ccm_project_name result
[[ "$result" == "${expected_result}" ]] && { printf "%10s\n" "SUCCESS" ; }|| { printf " FAILED: ${expected_result} != $result\n" ;}

ccm_query_name_instance_string="Create?NG_shared_MPC55xx_dev_ser"
ccm_query_instance="1"
expected_result="Create NG_shared_MPC55xx_dev_ser"
result=""
printf "%-8s: %-80s : %-75s " "test" "byref_translate_from_ccm_name_instance_query2ccm_name" "${ccm_query_name_instance_string} -> $expected_result"
byref_translate_from_ccm_name_instance_query2ccm_name $ccm_query_name_instance_string $ccm_query_instance result
[[ "$result" == "${expected_result}" ]] && { printf "%10s\n" "SUCCESS" ; }|| { printf " FAILED: ${expected_result} != $result\n" ;}

git_repo_name="Create-NG_shared_MPC55xx_dev_ser"
ccm_query_instance="1"
expected_result="Create NG_shared_MPC55xx_dev_ser"
result=""
printf "%-8s: %-80s : %-75s " "test" "byref_translate_from_git_repo2ccm_name" "${ccm_project_name} -> $expected_result"
byref_translate_from_git_repo2ccm_name $git_repo_name $ccm_query_instance result
[[ "$result" == "${expected_result}" ]] && { printf "%10s\n" "SUCCESS" ; }|| { printf " FAILED: ${expected_result} != $result\n" ;}

git_repo_4part="Create-NG_shared_MPC55xx_dev_ser~1_MD_SystemTesting_20130528:project:1"
expected_result="Create NG_shared_MPC55xx_dev_ser~1_MD_SystemTesting_20130528:project:1"
result=""
printf "%-8s: %-80s : %-75s " "test" "byref_translate_from_git_repo_4part2ccm_4part" "${git_repo_4part} -> $expected_result"
byref_translate_from_git_repo_4part2ccm_4part "$git_repo_4part" result
[[ "$result" == "${expected_result}" ]] && { printf "%10s\n" "SUCCESS" ; }|| { printf " FAILED: ${expected_result} != $result\n" ;}

ccm_4part="app_startup~1.0.x MD_SystemTesting_20130108:project:1"
expected_result="app_startup~1.0.x-MD_SystemTesting_20130108:project:1"
result=""
printf "%-8s: %-80s : %-75s " "test" "byref_translate_from_ccm_4part2git_repo_4part" "${ccm_4part} -> $expected_result"
byref_translate_from_ccm_4part2git_repo_4part "${ccm_4part}" result
[[ "$result" == "${expected_result}" ]] && { printf "%10s\n" "SUCCESS" ; }|| { printf " FAILED: ${expected_result} != $result\n" ;}

exit

$ sdebug=true ./ccm-get-translated_string.sh byref_translate_from_git_repo_4part2ccm_4part Create-NG_shared_MPC55xx_dev_ser 1
Create NG_shared_MPC55xx_dev_ser
$ ddebug=true ./ccm-get-translated_string.sh byref_translate_from_ccm_name2git_repo "Create NG_shared_MPC55xx_dev_ser"
Create-NG_shared_MPC55xx_dev_ser

