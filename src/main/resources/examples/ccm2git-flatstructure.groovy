package examples

/* vim: set syntax=groovy:set et:set tabstop=4: */

import org.slf4j.LoggerFactory

final log = LoggerFactory.getLogger(this.class)

if ( !System.getenv("ccm_delim") ){
    println "ccm_delim variable not set"
    System.exit(1)
else {
    println "ccm_delim: " + System.getenv("ccm_delim")
    ccm_delimiter = System.getenv("ccm_delim")
}


def ccm_project
def ccm_revision
def ccm_name4part
def ccm_instance
if ( !start_project?.trim() || !start_project.contains(':') || !start_project.contains(ccm_delimiter) ) {
    println "start_project not set correctly \n" +
            "Provide the start_project=<projectname>" + ccm_delimiter + "<revision>:project:<instance>"
    System.exit(1)
} else {
    ccm_name4part = start_project.trim()
    ccm_project = start_project.split(ccm_delimiter)[0]
    ccm_revision = start_project.split(ccm_delimiter)[1].split(':')[0]
    ccm_instance = start_project.split(ccm_delimiter)[1].split(':')[2]

    if ( ! ccm_project ) {
        println "Could not extract ccm_project name from start_project"
        System.exit(1)
    }
    if ( !ccm_revision || ccm_revision.contains(':') || ccm_revision.contains('~') ) {
        println "ccm_revision contains ':' \n" +
                "Provide the start_project=<projectname>" + ccm_delimiter + "<revision>:project:<instance>"
        System.exit(1)
    }
    if ( !ccm_instance || ccm_instance.contains(':') || ccm_instance.contains('~') ) {
        println "ccm_instance contains ':' or '~' \n" +
                "Provide the start_project=<projectname>" + ccm_delimiter + "<revision>:project:<instance>"
        System.exit(1)
    }
    if ( !ccm_name4part.contains(':') || !ccm_name4part.contains(ccm_delimiter) ) {
        println "Provide the start_project=<projectname>" + ccm_delimiter + "<revision>:project:<instance>"
        System.exit(1)
    }
}

def ccm_addr_cli
if ( !System.getenv("CCM_ADDR") ){
    println "CCM_ADDR system variable not set. Please start session prior to calling the ccm2git \n \
( ex: ccm start -m -d /data/ccmdb/<db> -s http://<server>:<port> -q ) "
    System.exit(1)
} else {
    ccm_addr_cli = System.getenv("CCM_ADDR")
}

def ccm_home_cli
if ( !System.getenv("CCM_HOME") ){
    println "CCM_HOME variable not set"
    System.exit(1)
} else {
    ccm_home_cli = System.getenv("CCM_HOME")
}
def system_path2 = System.getenv("PATH")

def my_workspace
if ( !my_workspace_root ) {
    my_workspace_root = "/data/Synergy/ccm2git-main"
    my_workspace = my_workspace_root + "/" + ccm_project + "/"
} else {
    my_workspace = my_workspace_root + "/" + ccm_project + "/"
}

def git_server_path_this
if ( !git_server_path ){
    System.exit(1)
} else {
    git_server_path_this = git_server_path
}


def jira_project_key_this
if ( !jiraProjectKey ) {
    println "Please set jiraProjectKey variable\n"
    System.exit(1)
} else {
    jiraProjectKeyThis = jiraProjectKey
}

def my_workspace_file = new File(my_workspace)
if(!my_workspace_file.exists()) my_workspace_file.mkdirs()
my_workspace_file = new File(my_workspace + "/ccm_wa")
if(!my_workspace_file.exists()) my_workspace_file.mkdirs()


source('ccm') {
    workspace "${my_workspace}/ccm_wa"
    revision start_project
    proj_instance ccm_instance
    name4part ccm_name4part
    ccm_addr ccm_addr_cli
    ccm_home ccm_home_cli
    system_path system_path2
    jiraProjectKey jiraProjectKeyThis
}

target('git', repository_name) {
    workspace "${my_workspace}/repo/" + ccm_project
    user 'Claus Schneider(Eficode)'
    email 'claus.schneider.ext@safrangroup.com'
    remote "ssh://git@${git_server_path_this}/${ccm_project}.git"
    longPaths true
    ignore ""
}

migrate {
    filters {
        filter {
            criteria {
                AlreadyConverted(target.workspace)
            }
            extractions {
                baselineProperties(source.workspace, source.jiraProjectKey)
            }
            actions {

                // Scrub Git repository, so file deletions will also be committed
                cmd 'git reset --hard -q $gitBaselineRevision_wstatus', target.workspace

                custom {
                    log.info "Removing files except .git folder in: $target.workspace"
                    new File(target.workspace).eachFile { file ->
                        if(!file.name.startsWith(".git")) {
                            if (!file.isDirectory()) {
                                println file.getName()
                                file.delete()
                            } else {
                                println file.getName()
                                file.deleteDir()
                            }
                        }
                    }
                    log.info "Remaining files except .git folder in: $target.workspace"
                    new File(target.workspace).eachFile { file ->
                        if(!file.name.startsWith(".git")) println file.getName()
                    }
                }

                // Copy checked out into Git repository
                copy("$source.workspace/code/\${gitSnapshotName}" + System.getenv("ccm_delim") + "\${gitSnapshotRevision}/\$gitSnapshotName", target.workspace)

                custom {
                    log.info "First level files in: $target.workspace"
                    new File(target.workspace).eachFile { file ->
                        if(!file.name.startsWith(".git")) println file.getName()
                    }
                }

                // Remove all .gitignore, .gitmodules, .gitattributes except in root folder
                cmd "bash git-remove-all-git-related-files-2plus-levels.sh " + target.workspace, System.getProperty("user.dir")
                // Add everything and renormalize attributes
                cmd 'git add -A --force .', target.workspace
                cmd 'git add --renormalize -A --force .', target.workspace

                // Fill empty dirs with .gitignore for empty directories
                cmd "bash git-fill-empty-dirs-with-gitignore.sh " + target.workspace, System.getProperty("user.dir")
                // Add everything
                cmd 'git add -A --force .', target.workspace

                // Update index to have executables on specific extensions
                cmd "bash git-set-execute-bit-in-index-of-extensions.sh " + target.workspace, System.getProperty("user.dir")

                // Update index to have executables based on unix tool file reporting
                cmd "bash git-set-execute-bit-in-index-of-unix-tool-file-executable.sh " + target.workspace, System.getProperty("user.dir")

                custom { project ->
                    def sout = new StringBuilder(), serr = new StringBuilder()

                    new File(target.workspace + File.separator + ".." + File.separator + "commit_meta_data.txt").withWriter { out ->
                        project.baseline_commit_info.each {
                            out.println it
                        }
                    }

                    def email_domain = '@eficode.com'
                    def envVars = System.getenv().collect { k, v -> "$k=$v" }
                    envVars.add('GIT_COMMITTER_DATE=' + project.snapshot_commiter_date)
                    envVars.add('GIT_AUTHOR_DATE=' + project.snapshot_commiter_date)
                    log.info("project.snapshotOwner: " + project.snapshotOwner)
                    if ( project.snapshotOwner != null ){
                        envVars.add('GIT_AUTHOR_NAME=' + project.snapshotOwner )
                        envVars.add('GIT_AUTHOR_EMAIL=' + project.snapshotOwner + email_domain)
                    }
                    def cmd_line = 'git commit --file ../commit_meta_data.txt'
                    log.info cmd_line.toString()
                    try {
                        def cmd = cmd_line.execute(envVars, new File(target.workspace))
                        cmd.waitForProcessOutput(sout, serr)
                        def exitValue = cmd.exitValue()
                        log.info "Standard out: " + "\n" + sout.toString()
                        if (exitValue) {
                            if ( ! sout.contains('nothing to commit, working tree clean') ){
                                log.error "Standard error:" + "'" + serr.toString() + "'"
                                log.error "Exit code: " + exitValue
                                throw new Exception(cmd_line + ": gave exit code: $exitValue")
                            } else {
                                log.info "Nothing commit - skip, but still tag"
                            }
                            if (serr.toString().readLines().size() > 0) {
                                log.error "Standard error: " + "'" + serr.toString() + "'"
                                log.error "Exit code: " + exitValue
                                throw new Exception(cmd_line + ": standard error contains text lines: " + serr.toString().readLines().size())
                            }
                        }
                        if (serr.toString().readLines().size() > 0) {
                            log.info (cmd_line + ": standard error contains text lines: " + serr.toString().readLines().size())
                            log.info "Standard error:" + "'" + serr.toString() + "'"
                        }
                    } catch (Exception e) {
                        log.error('An error occurred during the git commit..')
                        log.error(e.toString())
                        throw e
                    }

                }

                // Reset to test that git return to workspace is identical except the .git* files that are manipulated (removed Synergy snapshot .git files and added .gitignore to empty dirs
                custom {
                    log.info "Removing files except .git folder in: $target.workspace"
                    new File(target.workspace).eachFile { file ->
                        if(!file.name.startsWith(".git")) {
                            if (!file.isDirectory()) {
                                println file.getName()
                                file.delete()
                            } else {
                                println file.getName()
                                file.deleteDir()
                            }
                        }
                    }
                }
                cmd 'git reset --hard -q HEAD', target.workspace
                cmd 'diff -r -q -x ".gitignore" -x ".gitattributes" -x ".gitmodules" -x ".git" . ' + source.workspace + '/code/${gitSnapshotName}-${gitSnapshotRevision}/${gitSnapshotName}', target.workspace

                // The file for tag info is generated during MetaDataExtraction
                custom { project ->
                    new File(target.workspace + File.separator + ".." + File.separator + "tag_meta_data.txt").withWriter { out ->
                        project.baseline_tag_info.each {
                            out.println it
                        }
                    }
                }
                custom { project ->
                    def sout = new StringBuilder(), serr = new StringBuilder()
                    def cmd_line = "git tag -F ../tag_meta_data.txt " + project.gitSnapshotRevision + "_" + project.snapshot_status
                    log.info cmd_line

                    def email_domain = '@eficode.com'
                    def envVars = System.getenv().collect { k, v -> "$k=$v" }
                    envVars.add('GIT_COMMITTER_DATE=' + project.snapshot_commiter_date)
                    envVars.add('GIT_AUTHOR_DATE=' + project.snapshot_commiter_date)
                    log.info("project.snapshotOwner: " + project.snapshotOwner)
                    if ( project.snapshotOwner != null ){
                        envVars.add('GIT_COMMITTER_NAME=' + project.snapshotOwner )
                        envVars.add('GIT_COMMITTER_EMAIL=' + project.snapshotOwner + email_domain)
                    }
                    def cmd = cmd_line.execute(envVars,new File(target.workspace))
                    cmd.waitForProcessOutput(sout, serr)
                    def exitValue = cmd.exitValue()
                    log.info "Standard out:"
                    println "'" + sout.toString() + "'"
                    if ( exitValue ){
                        log.info "Standard error:"
                        println "'" + serr.toString() + "'"
                        log.info "Exit code: " + exitValue
                        throw new Exception(cmd_line + ": gave exit code: $exitValue" )
                    }
                    if ( serr.toString().readLines().size() > 0 ){
                        log.info "Standard error:"
                        println "'" + serr.toString() + "'"
                        log.info "Exit code: " + exitValue
                        throw new Exception(cmd_line + ": standard error contains text lines: " + serr.toString().readLines().size() )
                    }
                }

                cmd 'du -sBM .git > ../${gitSnapshotName}' + System.getenv("ccm_delim") + '${gitSnapshotRevision}@git_size.txt', target.workspace
                cmd 'cat ../${gitSnapshotName}' + System.getenv("ccm_delim") + '${gitSnapshotRevision}@git_size.txt', target.workspace

            }
        }
    }
}
