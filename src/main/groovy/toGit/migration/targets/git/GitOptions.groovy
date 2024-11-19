package toGit.migration.targets.git

class GitOptions {
    List<String> ignore = []
    List<String> lfs = []
    String user = 'migration'
    String email = '2git@praqma.com'
    String remote = ''
    String initCommitDate = "1970-01-01 00:00"

    String jiraProjectKey = ""

    boolean defaultSetup = true
    boolean longPaths = false
}
