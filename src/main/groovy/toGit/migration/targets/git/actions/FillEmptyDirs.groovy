package toGit.migration.targets.git.actions

import org.slf4j.LoggerFactory
import org.apache.commons.io.FileUtils
import toGit.migration.plan.Action

class FillEmptyDirs extends Action {

    final static log = LoggerFactory.getLogger(this.class)

    String path

    public FillEmptyDirs(String path) {
        this.path = path
    }

    @Override
    void act(HashMap<String, Object> extractionMap) {
        log.info("Sprinkling dummy files in empty directories")
        sprinkleDummies(new File(path))
        log.info("Finished sprinkling dummy files")
    }

    def sprinkleDummies(File directory) {
        def subDirs = directory.listFiles().findAll { it.isDirectory() && !it.name.equals(".git") }
        subDirs.each { subDir ->
            def contents = subDir.listFiles()
            if(contents.any()) {
                sprinkleDummies(subDir)
            } else {
                FileUtils.copyFileToDirectory(new File(System.getProperty("user.dir") + File.separator + "emptydir.gitignore"), targetDir)
                log.info("Dropped .gitignore file in $subDir")
            }
        }
    }
}
