---
name: review-multiple-prs
description: Review multiple pull requests in parallel by spinning up one review agent per PR, then consolidating findings into a single cross-PR summary. Use this when reviewing 2+ PRs that need to be understood together — stacked, parallel feature work, or a release batch.
disable-model-invocation: false
---

# Review Multiple PRs (Parallel)

Use this skill when the user provides 2 or more PR numbers or URLs to review. Unlike `/code-review` (which processes PRs sequentially), this skill fans out to parallel agents — one per PR — then merges their findings into a unified summary.

---

## Step 0 — Verify `gh` auth and repo access

1. Run `gh auth status`. If unauthenticated, stop and tell the user.
2. Resolve the repo identity: if PR URLs were provided, extract `owner/repo` from them. Otherwise run `gh repo view --json nameWithOwner -q .nameWithOwner` to get the repo from the current directory context. Store this as `{owner}/{repo}` — it is required for API calls in Step 5.
3. Run `gh repo view {owner}/{repo}` to confirm read access. If it fails, stop and tell the user.

## Step 1 — Identify and classify the PRs

- Collect all PR numbers / URLs from the user's message.
- If no PRs are specified, run the **PR Discovery** flow below before proceeding.
- If fewer than 2 PRs are provided (and discovery was not run), redirect the user to `/code-review` instead.

### PR Discovery (when no PRs are specified)

Use `gh` and the GitHub search API to find open PRs by the user's teammates that are awaiting review. Run these steps:

1. **Resolve the org:** extract the org from the `{owner}/{repo}` resolved in Step 0 (e.g. `ProjectAussie`).

2. **Find teammate usernames:** ask the user for a list of names or GitHub handles to search for. If they provide display names (e.g. "Claire", "Tom McT"), resolve them to GitHub logins by searching org members:
   ```
   gh api 'orgs/{org}/members' --paginate --jq '.[] | select(.login | test("{name}"; "i")) | .login'
   ```

3. **Find open PRs by those authors:**
   ```
   gh search prs --state open --author {login} --json number,title,url,author,repository --limit 20
   ```
   Run one search per author. Collect all results.

4. **Filter to actionable PRs only** — for each PR, fetch its review status:
   ```
   gh pr view <number> -R <owner/repo> --json reviewDecision,isDraft,reviewRequests
   ```
   Keep only PRs where:
   - `isDraft: false`, AND
   - `reviewDecision` is `"REVIEW_REQUIRED"` or `""` (empty = no decision yet), AND
   - `reviewDecision` is NOT `"APPROVED"`

5. **Bucket by requester type:**
   - **Your individual review:** PRs where `reviewRequests` contains the current user's login (`gh api user --jq .login`)
   - **Team approval:** PRs with `REVIEW_REQUIRED` but no individual review request for you — these are waiting on a team

6. **Present the list to the user** grouped by author and bucket, with URLs. Ask: "Should I review all of these, or select a subset?"

7. Once the user confirms the set, continue with the normal Step 1 classification flow using those PRs.
- For each PR, run `gh pr view <number> --json number,title,state,isDraft,baseRefName,headRefName,createdAt` to get metadata.
- Determine the relationship between the PRs:

  | Relationship | Definition | Review strategy |
  |---|---|---|
  | **Stacked** | Each PR targets the previous PR's branch | Review in merge order; pass raw diff context forward |
  | **Parallel** | Multiple PRs for the same feature, split by concern | Review independently; flag integration risks |
  | **Batch / Unrelated** | Unrelated changes reviewed together (e.g. release batch) | Review fully independently |

- State your interpretation to the user and **wait for explicit confirmation before fanning out**. Do not proceed until the user confirms or corrects the relationship classification. A misclassified stacked set will silently skip context forwarding — this confirmation gate is not optional.

## Step 2 — Fan out: one agent per PR

Spin up one Agent per PR using `subagent_type: general-purpose`. Name each agent after a unique American outlaw from the 1800s–1900s (e.g. Jesse James, Belle Starr, Black Bart, Dutch Schultz, Pretty Boy Floyd, Billy the Kid, Bonnie Parker). Names must be unique per session — do not reuse a name even if reviewing many PRs.

Each agent receives a self-contained prompt with:

1. The PR number, repo (`{owner}/{repo}`), and `is_draft` flag.
2. Instructions to:
   - Fetch the diff: `gh pr diff <number>` — save this output; it is the authoritative source of changed lines for inline comment line numbers
   - Read the PR metadata and comments: `gh pr view <number> --comments`
   - Check CI: `gh pr checks <number>` — note that this only shows current run state; to assess whether failures are pre-existing, also run `gh pr checks <base-branch>` or `gh pr checks $(gh pr view <number> --json baseRefName -q .baseRefName)` for comparison. If base-branch checks are also failing, mark `ci_failures_introduced_by_pr: false`.
   - Read the linked Jira ticket via the Atlassian MCP if a ticket key is found in the branch name or PR description
   - Read surrounding code for any renamed functions, changed contracts, or modified public APIs
3. **For stacked PRs only:** the raw output of `gh pr diff <prior-number>` from the prior agent — passed verbatim, not summarized — so the agent understands what the prior layer changed and can attribute findings to the correct PR.
4. **Draft PR behavior:** if `is_draft: true`, the agent must still review and produce findings, but must set `verdict: "COMMENT"` unconditionally. It should still post inline comments (authors expect feedback on drafts) but the summary must clearly label the PR as a draft.
5. The review dimensions to evaluate (see Step 3 below)
6. The finding severity scale (see Step 4 below)
7. Instructions to **return findings as structured JSON** (see Output Contract below)

Run all agents in parallel (single message, multiple tool calls) **unless** the PRs are stacked — in that case, run them sequentially in merge order so each agent gets the prior layer's raw diff as context.

### Output Contract

Each agent must return a JSON object with exactly these fields:

```json
{
  "pr": 123,
  "title": "...",
  "verdict": "APPROVE",
  "is_draft": false,
  "ci_status": "passing",
  "ci_failures_introduced_by_pr": false,
  "stacked_context_diff": "<raw output of gh pr diff for this PR — included only for stacked PRs, to pass forward to the next agent>",
  "findings": [
    {
      "severity": "BLOCKER",
      "file": "path/to/file.ts",
      "line": 42,
      "body": "..."
    }
  ],
  "summary": "2–4 sentence summary of what the PR does and overall quality"
}
```

Valid `verdict` values: `"APPROVE"`, `"REQUEST_CHANGES"`, `"COMMENT"`.

**Line number constraint:** every finding with a `line` value must reference a line that actually appears in the diff output from `gh pr diff`. Do not invent or approximate line numbers — a line number not in the diff will cause the GitHub API to reject the comment with a 422 error.

## Step 3 — Review dimensions (per PR)

Each agent evaluates:

### Correctness
- Does the code do what the PR description says?
- Off-by-one errors, missing null checks, unhandled edge cases?
- Are error paths handled?

### Security
- OWASP Top 10: injection, broken auth, insecure deserialization, XSS, etc.
- Hardcoded secrets? Inputs validated at system boundaries?
- Least-privilege principle followed?

### Design & Simplicity
- Is the abstraction level appropriate?
- Unnecessary indirection or over-engineering?
- Could anything be deleted with no behavior change?

### Readability & Maintainability
- Clear variable and function names?
- Complex logic commented where intent isn't obvious?
- Dead code, debug artifacts, commented-out blocks left in?

### Test Coverage
- Tests for the new behavior?
- Do existing tests still make sense? Are mocks hiding real integration issues?
- Edge cases covered?

### Performance (only if relevant)
- Obvious N+1 queries, unnecessary loops, unindexed DB calls?
- Heavy computation in request paths?

## Step 4 — Finding severity scale

| Level | Meaning |
|---|---|
| **BLOCKER** | Must be fixed before merge. Correctness bug, security vuln, broken contract, CI failure introduced by this PR. |
| **HIGH** | Serious design or reliability issue. Should fix; discuss if deferring. |
| **MEDIUM** | Real improvement, not blocking. Author should address or explicitly accept risk. |
| **LOW / NIT** | Style, naming, minor cleanup. Don't block merge over these. |
| **QUESTION** | Unclear intent — ask before judging. |
| **PRAISE** | Something done especially well. Say it. |

Do not manufacture findings to look thorough. If the code is good, say so.

## Step 5 — Post inline comments

After collecting all agent outputs, post inline comments for each PR using `gh api`. Use `side: "RIGHT"` for all inline comments (the right side of the split diff — the new version). Only post comments for lines confirmed to exist in the diff.

```
gh api repos/{owner}/{repo}/pulls/{number}/reviews \
  --method POST \
  --field body="" \
  --field event="COMMENT" \
  --field "comments[][path]=path/to/file.ts" \
  --field "comments[][line]=42" \
  --field "comments[][side]=RIGHT" \
  --field "comments[][body]=Farty Bobo {VERB}: <finding>"
```

Post inline comments for all PRs before writing the consolidated summary.

## Step 6 — Post consolidated summary

After all inline comments are posted, post a **single top-level comment on each PR** with that PR's individual summary, followed by a **cross-PR summary comment** on the lowest-numbered PR (or the base PR for stacked work).

### Per-PR comment format

```
## Farty Bobo's Code Review

**Verdict:** APPROVE / REQUEST_CHANGES / COMMENT
_(Draft PR — full review pending merge readiness)_  ← include only if is_draft: true

### Summary
<2–4 sentences>

### Findings

#### BLOCKER
- `path/to/file.ts:42` — <finding>

#### HIGH
- `path/to/file.ts:42` — <finding>

#### MEDIUM
- ...

#### LOW / NIT
- ...

#### Questions
- ...

#### What's Good
- <something done well>

---
_Reviewed by Farty Bobo_
```

Only include sections that have entries. Omit empty sections entirely.

### Cross-PR summary format (posted once, on lowest-numbered PR)

```
## Farty Bobo's Cross-PR Review — <PR list>

### Relationship
<Stacked / Parallel / Batch — and why>

### Overall Verdict
<One of: ALL APPROVE / MIXED / ALL REQUEST_CHANGES>

| PR | Title | Verdict | Blockers | Highs |
|----|-------|---------|----------|-------|
| #123 | ... | APPROVE | 0 | 1 |
| #124 | ... | REQUEST_CHANGES | 1 | 0 |

### Integration Concerns _(if applicable)_
<Cross-PR issues that don't belong to a single PR — naming conflicts, shared state, ordering dependencies, duplicated logic across PRs>

### Merge Order _(if applicable — stacked or ordered PRs only)_
1. #123 — merge first
2. #124 — depends on #123

---
_Reviewed by Farty Bobo_
```

Only include sections with content. Omit empty sections.

### Verdict rules (per PR)

- `APPROVE` — no BLOCKERs or HIGHs, CI passing (or failures pre-existing on base)
- `REQUEST_CHANGES` — one or more BLOCKERs or HIGHs introduced by this PR
- `COMMENT` — draft PR, questions only, or observations with no blocking concerns

## Step 7 — Notify the user

After posting all comments:

- Report the per-PR verdicts and total finding counts.
- Call out any cross-PR integration concerns surfaced.
- If CI failures were introduced by any PR, name the PR and suggest `/resolve-ci-failures`.
- If any PRs have BLOCKERs or HIGHs, list the top concerns briefly.
- This skill covers one review pass. Re-invoke after the author pushes new commits.
