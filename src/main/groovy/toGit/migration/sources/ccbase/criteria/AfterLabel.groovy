package toGit.migration.sources.ccbase.criteria

import toGit.migration.plan.Criteria
import toGit.migration.plan.Snapshot

class AfterLabel extends Criteria{

    String label

    AfterLabel(String label) {
        this.label = label;
    }

    @Override
    boolean appliesTo(Snapshot snapshot) {
        // Assumes alphabetical sorting == date sorting
        return label.compareTo(snapshot.identifier) < 0
    }
}