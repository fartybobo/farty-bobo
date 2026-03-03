---
name: git skill
description: Use when working on code changes & code reviews
---

# Git Best Practices Skill

1. Review all staged and unstaged changes.
2. Run githooks in individual repos before committing and fix errors (linting, type checks, tests). Most repos have dedicated commands to achieve these goals either in package.json or pyproject.toml
3. When creating new branches, ask the user to provide a JIRA ticket id. All new branches must have the format: `kinano/{ticket-id}-{short-description}`
4. When committing changes, summarize the changes in staged files. Always prefix commits with [{ticket-id}]: {summary of change}.
5. Commit and push. If the push fails due to errors NOT related to our changes, use `git push --no-verify`
6. Create a draft PR using `gh pr create --draft` with a clear title and description summarized from the context.
7. Output the PR URL.
