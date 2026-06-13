# Claude Code Plugin Architecture

## How Skills are Registered

Claude Code plugins use a **directory convention** combined with **explicit registration** in `plugin.json`.

### Discovery Mechanism

Skills follow a directory convention (`skills/<name>/SKILL.md`) and are explicitly listed in the `skills` array in `plugin.json`.

**Requirements for skill registration:**
1. File location: `skills/<skill-name>/SKILL.md`
2. YAML frontmatter with required fields:
   ```yaml
   ---
   name: skill-name
   description: Brief description of what the skill does
   ---
   ```
3. Execution instructions in markdown body (after frontmatter)
4. Skill path listed in the `skills` array in `.claude-plugin/plugin.json`

### Plugin Structure

```
.claude-plugin/
├── plugin.json           # Metadata + skills array (explicit skill registration)
└── marketplace.json      # Marketplace listing info

skills/
├── draft/SKILL.md        # Discovered as /draft:draft or /draft
├── init/SKILL.md         # Discovered as /draft:init
├── new-track/SKILL.md    # Discovered as /draft:new-track
├── bughunt/SKILL.md      # Discovered as /draft:bughunt
└── ...                   # All other skills
```

### What plugin.json Contains

The `plugin.json` file contains **metadata** and a **skills directory path** pointing to the skills folder:

```json
{
  "name": "draft",
  "description": "...",
  "version": "2.6.0",
  "author": { "name": "..." },
  "homepage": "...",
  "license": "MIT",
  "keywords": [...],
  "skills": "./skills/"
}
```

**Note:** The `skills` field uses a directory convention — Claude Code discovers all `SKILL.md` files under the specified directory. Skills must follow the naming convention (`skills/<name>/SKILL.md`).

### Verification

To verify a skill is registered, check that:

1. ✅ SKILL.md file exists in `skills/<name>/`
2. ✅ Frontmatter has `name:` and `description:` fields
3. ✅ Skill appears in generated integration files
4. ✅ Skill is in `SKILL_ORDER` array in `build-integrations.sh` (for integrations)

**Example verification for bughunt:**

```bash
# 1. File exists
ls skills/bughunt/SKILL.md
# ✅ skills/bughunt/SKILL.md

# 2. Frontmatter is valid
head -5 skills/bughunt/SKILL.md
# ✅ ---
# ✅ name: bughunt
# ✅ description: Exhaustive bug hunt using Draft context...
# ✅ ---

# 3. Appears in integrations
grep "@draft bughunt" integrations/gemini/GEMINI.md
# ✅ | `@draft bughunt [--track <id>]` | Systematic bug discovery |
# ✅ When user says "hunt bugs" or "@draft bughunt [--track <id>]":

# 4. In build script
grep "bughunt" scripts/build-integrations.sh
# ✅ SKILL_ORDER=( ... bughunt ... )
# ✅ bughunt)      echo "Bug Hunt Command" ;;
# ✅ bughunt)      echo "\"hunt bugs\" or \"@draft bughunt [--track <id>]\"" ;;
```

### Command Naming

Skills are invoked using the `name` from frontmatter:

| Frontmatter `name:` | Claude Code Command | Cursor/Gemini | Copilot |
|---------------------|---------------------|---------------|---------|
| `draft` | `/draft:draft` or `/draft` | `@draft` | `draft` |
| `init` | `/draft:init` | `@draft init` | `draft init` |
| `bughunt` | `/draft:bughunt` | `@draft bughunt` | `draft bughunt` |
| `new-track` | `/draft:new-track` | `@draft new-track` | `draft new-track` |

### Adding a New Skill

To add a new skill to the Draft plugin:

1. **Create the skill file:**
   ```bash
   mkdir -p skills/my-skill
   cat > skills/my-skill/SKILL.md << 'EOF'
   ---
   name: my-skill
   description: What this skill does
   ---

   # Skill execution instructions

   Step 1: ...
   Step 2: ...
   EOF
   ```

2. **Add to build script** (for integration generation):
   ```bash
   # Edit scripts/build-integrations.sh
   # Add to SKILL_ORDER array:
   SKILL_ORDER=(
       draft
       init
       new-track
       my-skill    # <-- Add here
       ...
   )

   # Add to get_skill_header():
   get_skill_header() {
       case "$skill" in
           ...
           my-skill) echo "My Skill Command" ;;
       esac
   }

   # Add to get_trigger():
   get_trigger() {
       case "$skill" in
           ...
           my-skill) echo "\"my skill\" or \"${prefix}draft my-skill\"" ;;
       esac
   }
   ```

3. **Verify plugin.json discovery:**
   ```bash
   # plugin.json uses directory convention ("skills": "./skills/")
   # New skills are auto-discovered — no manual registration needed
   ```

4. **Rebuild integrations:**
   ```bash
   make build
   ```

5. **Test:**
   ```bash
   # In Claude Code:
   /draft:my-skill

   # In Cursor:
   @draft my-skill

   # In Copilot:
   draft my-skill
   ```

### Registration Model

**Directory convention + auto-discovery:**
- Skills follow a consistent directory structure (`skills/<name>/SKILL.md`)
- `plugin.json` uses a directory path (`"skills": "./skills/"`) for auto-discovery
- The build script uses `SKILL_ORDER` for integration generation ordering

**Tradeoffs:**
- ⚠️ Skill must follow naming convention (`skills/<name>/SKILL.md`)
- ⚠️ Must add to `SKILL_ORDER` in the build script for integration generation
- ⚠️ Name collision possible if not careful

---

**Last Updated:** 2026-04-10
**Plugin Version:** 2.6.0
