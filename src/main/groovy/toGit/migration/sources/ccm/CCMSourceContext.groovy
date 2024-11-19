package toGit.migration.sources.ccm

import toGit.context.base.Context
import toGit.context.traits.SourceContext


class CCMSourceContext implements Context, SourceContext {
    public CCMSourceContext() {
        source = new CCMSource()
    }


    /**
     * Sets the source workspace
     */
    void workspace(String path) {
        source.workspace = path
        //log.debug("Set workspace to $path.")
    }

    void revision (String revision){
        source.revision = revision
    }

    void name4part (String name4part){
        source.name4part = name4part
    }
    void proj_instance (String proj_instance){
        source.proj_instance = proj_instance
    }

    void ccm_addr (String ccm_addr){
        source.ccm_addr = ccm_addr
    }

    void ccm_home (String ccm_home){
        source.ccm_home = ccm_home
    }

    void system_path (String system_path){
        source.system_path = system_path
    }

    void jiraProjectKey (String jiraProjectKey){
        source.jiraProjectKey = jiraProjectKey
    }
}
