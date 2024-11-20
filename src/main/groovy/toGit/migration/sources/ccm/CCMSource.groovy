package toGit.migration.sources.ccm

import org.apache.commons.io.FileUtils
import org.slf4j.LoggerFactory

import toGit.context.base.Context
import toGit.migration.plan.Criteria
import toGit.migration.plan.Snapshot
import toGit.migration.sources.MigrationSource
import toGit.migration.sources.ccm.context.CcmCriteriaContext
import toGit.migration.sources.ccm.context.CcmExtractionsContext

class CCMSource implements MigrationSource {

    final static log = LoggerFactory.getLogger(this.class)

    String revision
    String proj_instance
    String name4part
    String ccm_addr
    String ccm_home
    String system_path
    String jiraProjectKey

    @Override
    List<Snapshot> getSnapshots(List<Criteria> initialFilter) {

        List<Snapshot> projects

        // Build the CCM project conversion list
        def sout = new StringBuilder(), serr = new StringBuilder()
        def cmd_line = ["bash", System.getProperty("user.dir") + File.separator + "ccm-baseline-history.sh", "${name4part}"]

        log.info cmd_line.toString()

        def envVars = System.getenv().collect { k, v -> "$k=$v" }
        def cmd = cmd_line.execute(envVars,new File(workspace))
        cmd.waitForProcessOutput(sout, serr)
        def exitValue = cmd.exitValue()

        println (sout.toString())
        if ( exitValue ){
            println ("Standard error output" )
            println (serr.toString())
            throw new Exception("ccm-baseline-history gave an non-0 exit code" )
        }
        if ( serr.toString().readLines().size() > 0 ){
            println ("Standard error output - used for SKIP projects" )
            println (serr.toString())
        }

        projects = sout.readLines().collect{new Snapshot(it){}}

        log.info projects.size().toString()

        return projects
    }

    @Override
    void checkout(Snapshot snapshot) {
        copy2Filesystem(snapshot)
    }

    private void copy2Filesystem(Snapshot snapshot) {
        def gitSnapshotThis = snapshot.identifier.split("@@@")[0]
        def gitSnapshotBaseline = snapshot.identifier.split("@@@")[1]
        def gitSnapshotName = gitSnapshotThis.split(System.getenv("ccm_delim"))[0]
        def gitSnapshotRevision = gitSnapshotThis.split(System.getenv("ccm_delim"))[1].split(":")[0]
        def gitSnapshotInstance = gitSnapshotThis.split(System.getenv("ccm_delim"))[1].split(":")[2]
        def gitBaselineRevision = gitSnapshotBaseline.split(System.getenv("ccm_delim"))[1].split(":")[0]
        def gitBaselineInstance = gitSnapshotBaseline.split(System.getenv("ccm_delim"))[1].split(":")[2]

        def ccmSnapshotThis = snapshot.identifier.split("@@@")[2]
        def ccmSnapshotName = ccmSnapshotThis.split(System.getenv("ccm_delim"))[0]
        def ccmSnapshotBaseline = snapshot.identifier.split("@@@")[3]

        def gitSnapshot_revision_for_ws=gitSnapshotThis.split(":")[0]

        def codeFile = new File(workspace, "code")
        codeFile.parentFile.mkdirs()
        if ( ! codeFile.exists()) {
            codeFile.delete()
        }
        codeFile.mkdir()


        def path_final=workspace + "/code/" + gitSnapshot_revision_for_ws
        def file_full_path_name="${path_final}/" + gitSnapshotName

        if ( new File(file_full_path_name).exists()){
            log.info "CM/Synergy checkout: Skipping project revision: ${gitSnapshot_revision_for_ws} - already exists"
        } else {
            def sout = new StringBuilder(), serr = new StringBuilder()
            def path_tmp="${path_final}_tmp"

            def file_tmp = new File(path_tmp)
            if ( file_tmp.exists() ){
                log.info "${path_tmp} exist - Delete it "
                file_tmp.deleteDir()
            }

            def file_full_path_spaced_name = new File ("${path_final}/" + ccmSnapshotThis.split(snapshot.ccm_delimiter)[0])
            if ( file_full_path_spaced_name.exists() ) {
                log.info file_full_path_spaced_name.toString() + " exist due to previous error - Delete it all"
                def file_base = new File (path_final)
                file_base.deleteDir()
            }

            def envVars = System.getenv().collect { k, v -> "$k=$v" }
            def cmd_line = ["ccm", "copy_to_file_system", "-p", "${gitSnapshot_revision_for_ws}_tmp", "-r", "${ccmSnapshotThis}"]
            log.info "'" + cmd_line + "'"
            def cmd = cmd_line.execute(envVars,codeFile)
            cmd.waitForProcessOutput(sout, serr)
            def exitValue = cmd.exitValue()
            log.info "Standard out:"
            log.info "'" + sout + "'"
            log.info "Standard error:"
            log.info "'" + serr + "'"
            log.info "Exit code: " + exitValue
            if ( exitValue ){
                throw new Exception("ccm copy_to_file_system gave an non-0 exit code" )
            }
            if ( serr.toString().readLines().size() > 0 ){
                throw new Exception("ccm copy_to_file_system standard error contains text lines: " + serr.toString().readLines().size() )
            }

            if ( ! new File(path_tmp + "/" + ccmSnapshotName ).exists() ) {
                if ( ! new File(path_tmp).exists() ) {
                    log.info "Checkout is empty - make an empty dir: " + path_final
                    new File(path_tmp).mkdir()
                }
                log.info "Checkout is empty - make an empty dir: " + path_final + "/" + ccmSnapshotName + "/" + ccmSnapshotName
                new File(path_tmp + "/" + ccmSnapshotName).mkdir()
            }
            log.info "Move from: ${path_tmp} to: ${path_final}"
            FileUtils.moveDirectory(new File(path_tmp), new File(path_final))

            if ( gitSnapshotName != ccmSnapshotName  ){
                log.info "ccm and git names differ.. move ccm name to git name: " + path_final + "/" + ccmSnapshotName + " -> "  + file_full_path_name
                FileUtils.moveDirectory(new File(path_final + "/" + ccmSnapshotName), new File(file_full_path_name))
            }
        }
    }

    @Override
    void prepare() {

    }

    @Override
    void cleanup() {

    }

    @Override
    Context withCriteria(Context criteriaContext) {
        return criteriaContext as CcmCriteriaContext
    }

    @Override
    Context withExtractions(Context extractionsContext) {
        return extractionsContext as CcmExtractionsContext
    }
}
