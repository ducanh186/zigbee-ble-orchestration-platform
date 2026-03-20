# Git Workflow Rules
 
## Branch Naming
 
- Branch names must follow this format: `prefix/<jira-ticket-id>-<branch-description>`.
- Allowed `prefix` values are: `feature`, `bugfix`.
- Use lowercase kebab-case for `<branch-description>`.
- Example: if Jira ticket ID is `1` and description is `create code base`, the branch name is `feature/1-create-code-base`.
 
## Pull Request Rules
 
- All work must be merged into `main` through a pull request.
- Direct merge/commit to `main` is not allowed.
- Every pull request must be approved before merging.