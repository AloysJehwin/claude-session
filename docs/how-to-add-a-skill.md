# How to Add a Skill (Claude Code Custom Command)

Claude Code custom commands live in `~/.claude/commands/` as Markdown files. Each file becomes a `/slash-command` available in any Claude Code session.

## Directory

```
~/.claude/
└── commands/
    └── sonar-scan.md   ← skills live here
```

## Steps to install a skill from this repo

### 1. Clone or download

```bash
git clone https://github.com/AloysJehwin/claude-session.git
```

### 2. Copy the command file

```bash
mkdir -p ~/.claude/commands
cp claude-session/commands/sonar-scan.md ~/.claude/commands/
```

### 3. Fill in your credentials

Open `~/.claude/commands/sonar-scan.md` and replace the placeholders:

```
SONAR_HOST=https://sonar.your-company.com
SONAR_COMPONENT=com.example:your-project-key
SONAR_TOKEN=squ_your_token_here
```

Generate a token at: `$SONAR_HOST/account/security`

> **Never commit a file with a real token.** Keep your filled-in copy local only.

### 4. Use it

In any Claude Code session type:

```
/sonar-scan 42
```

or with a full PR URL:

```
/sonar-scan https://github.com/your-org/your-repo/pull/42
```

---

## How to write your own skill

1. Create a new `.md` file in `~/.claude/commands/`:

   ```bash
   touch ~/.claude/commands/my-skill.md
   ```

2. Structure it like this:

   ````markdown
   # my-skill

   One-line description of what this skill does.

   ## Usage
   ```
   /my-skill <arg>
   ```

   ## Instructions

   When this skill is invoked, do the following:

   1. Step one...
   2. Step two...
   ````

3. Invoke it immediately — no restart needed:

   ```
   /my-skill some-argument
   ```

## Tips

- Skills are plain Markdown — no code, no compilation.
- Instructions are read by Claude at invocation time, so you can be as detailed as needed.
- Keep credentials out of the file if you plan to share it — use placeholders and document them in a config section.
- Skills in `~/.claude/commands/` are **user-global** (all projects). Project-scoped skills go in `.claude/commands/` inside the repo.
