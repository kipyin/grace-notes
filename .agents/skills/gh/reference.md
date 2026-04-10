# gh CLI reference (Grace Notes)

Non-exhaustive patterns; adjust titles, bodies, and label lists to match the task.

## Labels and inventory

```bash
gh label list --limit 100
gh issue list --state open --limit 20 --json number,title,labels,milestone
gh pr list --state open --limit 20 --json number,title,labels
```

## Issue (after user confirms interview summary)

```bash
gh issue create --title "…" --body "…" --label "feat" --label "today" --label "p3"
# Milestone when user confirmed:
gh issue create --title "…" --body "…" --milestone "2026-W17" --label "chore" --label "infra"
```

## Branch and PR

```bash
git checkout main && git pull
git checkout -b feat/short-slug
# … commit …
git push -u origin HEAD
gh pr create --title "feat: … (#123)" --body "$(cat <<'EOF'
…
Closes #123
EOF
)"
```

## PR labels (mirror issue or apply taxonomy)

```bash
gh pr edit 123 --add-label "feat" --add-label "past" --add-label "p2"
gh pr edit 123 --add-label "full-ci"
```

## Comment after push

```bash
gh pr comment 123 --body "$(cat <<'EOF'
- …
- …
EOF
)"
```

## Reviews

```bash
gh pr view 123 --comments
gh api repos/:owner/:repo/pulls/123/comments
```

## Merge (only with user approval)

```bash
gh pr merge 123 --squash --subject "…" --body "Closes #456"
```
