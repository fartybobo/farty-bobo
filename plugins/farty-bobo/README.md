# farty-bobo

Selectively install skills, hooks, and commands from the [Farty Bobo config repo](https://github.com/fartybobo/farty-bobo) — without forking or cloning the whole thing.

## Installation

Add to your `~/.claude/settings.json` or any project-level `.claude/settings.json`:

```json
{
  "plugins": [
    "github:fartybobo/farty-bobo/plugins/farty-bobo"
  ]
}
```

## Usage

```
/farty-bobo:install
```

The skill will:
1. Fetch the current catalog of available skills, hooks, and commands from the repo
2. Let you pick what you want — all of it, or a subset
3. Download selected items to your machine
4. For hooks: ask whether to register them globally (`~/.claude/settings.json`) or scoped to the current project (`.claude/settings.json`)
