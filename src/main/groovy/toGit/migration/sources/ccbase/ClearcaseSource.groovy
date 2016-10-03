package toGit.migration.sources.ccbase

import org.slf4j.LoggerFactory
import toGit.context.base.Context
import toGit.migration.plan.Criteria
import toGit.migration.plan.Snapshot
import toGit.migration.sources.MigrationSource
import toGit.migration.sources.ccbase.context.ClearcaseCriteriaContext
import toGit.migration.sources.ccbase.context.ClearcaseExtractionsContext

class ClearcaseSource implements MigrationSource {

    final static log = LoggerFactory.getLogger(this.class)

    String configSpecPath = "C:\\path\\to\\spec.cs";

    @Override
    List<Snapshot> getSnapshots(List<Criteria> initialFilter) {
        return [new ClearcaseSnapshot('a_label')];
        //def txt = "cleartool lslabel ${configSpecPath[0]}".execute().text
        //def labels = txt.split(";")
        //return labels.collect{new ClearcaseSnapshot(it)}
    }

    @Override
    void checkout(Snapshot snapshot) {
        // Code to prepare a workspace for the given snapshot
        log.info('Done!')
    }

    @Override
    void prepare() {
        log.info("Creating snapshot view...")
        //Fixme get tag from script
        log.info("cleartool mkview -snapshot -tag whatever -stgloc -auto ${workspace}".execute().text)
        log.info("Setting config spec...")
        log.info("cleartool setcs ${configSpecAsFile().absolutePath}".execute([], new File(workspace)).text)
    }

    File configSpecAsFile() {
        def configSpec = new File(configSpecPath);
        if(!configSpec.exists() || configSpec.isDirectory()) {
            log.error("Could not find config spec at $configSpecPath")
            System.exit(1)
        }
        return configSpec;
    }

    @Override
    void cleanup() {
    }

    @Override
    Context withCriteria(Context criteriaContext) {
        return criteriaContext as ClearcaseCriteriaContext
    }

    @Override
    Context withExtractions(Context extractionsContext) {
        return extractionsContext as ClearcaseExtractionsContext
    }
}