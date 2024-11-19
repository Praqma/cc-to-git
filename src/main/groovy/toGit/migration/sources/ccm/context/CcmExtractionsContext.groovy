package toGit.migration.sources.ccm.context

import org.slf4j.Logger
import org.slf4j.LoggerFactory
import toGit.context.base.Context
import toGit.migration.sources.ccm.extractions.MetaBaseline

trait CcmExtractionsContext implements Context {
    final static Logger log = LoggerFactory.getLogger(this.class)

    /**
     * Extracts a CoolBaseline property
     * @param map A map of values to extract and keys to map them to.
     */
    void baselineProperties(String ccm_workspace, String jiraProjectKey) {
        extractions.add(new MetaBaseline(ccm_workspace, jiraProjectKey))
        log.debug("Added 'baselineProperties' criteria.")
    }
}
