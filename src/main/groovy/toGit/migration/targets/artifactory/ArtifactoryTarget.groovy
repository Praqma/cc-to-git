package toGit.migration.targets.artifactory

import org.jfrog.artifactory.client.Artifactory
import org.slf4j.LoggerFactory
import toGit.migration.targets.MigrationTarget
import toGit.migration.targets.artifactory.actions.Publish

import static org.jfrog.artifactory.client.ArtifactoryClient.create

class ArtifactoryTarget implements MigrationTarget {

    final static log = LoggerFactory.getLogger(this.class)

    Artifactory client
    ArtifactoryOptions options

    @Override
    void prepare() {
    }

    @Override
    void cleanup() {
        client.close()
    }

    /**
     * Publish given file to this Artifactory
     * @param path The artifact path to publish to
     * @param file The file to publish
     */
    def publish(String path, File file) {
        def pub = new Publish(getClient(), options.repository, path, file)
        addAction('publish', pub)
    }

    Artifactory getClient() {
        if (!client) client = create(options.url, options.user, options.password)
        return client
    }
}
