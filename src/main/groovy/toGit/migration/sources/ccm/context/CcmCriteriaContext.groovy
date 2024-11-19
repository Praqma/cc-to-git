package toGit.migration.sources.ccm.context

import org.slf4j.Logger
import org.slf4j.LoggerFactory
import toGit.context.base.Context

import toGit.migration.sources.ccm.criteria.AlreadyConverted

trait CcmCriteriaContext implements Context {
    final static Logger log = LoggerFactory.getLogger(this.class)


    /**
     * Filters out baselines that don't have given promotion levels
     * @param levels the promotion levels to test baselines against
     */
    void AlreadyConverted(String repo_path) {
        criteria.add(new AlreadyConverted(repo_path))
        log.debug("Added 'AlreadyConverted' criteria.")
    }
}
