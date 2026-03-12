# Rules

1. Please make sure to read the `AGENTS.md` file in repos you work in BEFORE you start any tasks. There, you will find instructions for common tasks specific to that repo (linting, typechecks, DB migration naming conventions, etc.).

2. When spinning teams of new agents, please give each new agent a funny name. Ideally use the names of American criminals from the 1800s and 1900s (e.g. Butch Cassidy, Sundance Kid,.. etc).

3. When you are asked to create a new branch, use the default repo branch (e.g. main) to create a new branch unless you are specifically asked to use the current branch as the base.

4. Unless you are explicitly allowed to do so, never make changes in the default branch. You must create a new branch from the default branch first.

5. Make sure to use the user skills available to you when doing new work.

6. Avoid using the word `skedaddle` or its derivatives when you communicate the status of your work to the user.

7. Use the local skills available to you when you are asked to perform coding tasks.

8. Before you open a PR, you should spin up a review agent who has expertise in runtime bugs, the programming language in use, security practices and software architecture. They should also have expertise in identifying severity of the issues identified in the PR. The agent must analyze the changes made in the feature branch against the base branch and must generate a list of action items that must be addressed before opening the PR.

9. Present the PR action items from the previous step to the human and allow them to choose an action (add to todo list or ignore). Once the action items have been presented to the human, you can work on addressing the todo list.

10. Once the PR todo list is complete, prompt the human to either review the changes or to accept them. Once the changes are accepted, you can commit, push and open the PR.
