# 🥔 Potato - Bash Extension Framework

**Potato** is a modular bash extension system that lets you add custom functionality to your shell through "toppings" - small, focused scripts that hook into bash at different execution points.

## Quick Start

```bash
# Add potato to your PATH and source it in ~/.bashrc
export PATH="$PATH:/path/to/potato-dir"
source potato__ startup
```

## What are Toppings?

Toppings are bash scripts that execute at specific lifecycle events in your shell. Think of them as plugins or hooks that extend bash functionality without cluttering your main configuration.

### Topping Types

Potato supports three types of toppings based on filename suffix:

| Type | Suffix | When It Runs | Use Cases |
|------|--------|--------------|-----------|
| **Startup** | `.bashrc` | Once when shell starts | Custom prompts, environment setup, aliases |
| **Pre-command** | `.precommand` | Before each command executes | Validation, warnings, command modification |
| **Post-command** | `.postcommand` | After each command completes | Logging, notifications, cleanup, state updates |

### How Toppings Work

```
┌─────────────────────────────────────────────────┐
│  Shell Startup                                  │
│  └─> All *.bashrc toppings load                │
└─────────────────────────────────────────────────┘
          ↓
┌─────────────────────────────────────────────────┐
│  User types command: cd /tmp                    │
└─────────────────────────────────────────────────┘
          ↓
┌─────────────────────────────────────────────────┐
│  All *.precommand toppings execute              │
│  (can inspect/modify/cancel command)            │
└─────────────────────────────────────────────────┘
          ↓
┌─────────────────────────────────────────────────┐
│  Command executes: cd /tmp                      │
└─────────────────────────────────────────────────┘
          ↓
┌─────────────────────────────────────────────────┐
│  All *.postcommand toppings execute             │
│  (can react to command results)                 │
└─────────────────────────────────────────────────┘
```

## Usage

### List Enabled Toppings

```bash
potato__ list
```

Output example:
```
Enabled toppings:
  git-prompt.bashrc
  command-logger.postcommand
  rm-warning.precommand
```

### Enable a Topping

```bash
potato__ enable /path/to/topping-name.bashrc
potato__ enable ./rm-warning.precommand
potato__ enable ../command-log.postcommand
```

The filename **must** follow the naming convention: `NAME.TYPE` where TYPE is one of:
- `bashrc` - for startup hooks
- `precommand` - for pre-execution hooks  
- `postcommand` - for post-execution hooks

### Disable a Topping

```bash
potato__ disable topping-name.bashrc
```

### Reload All Toppings

After enabling/disabling toppings:
```bash
source potato__ startup
```

Or restart your shell.

## Writing Toppings

### Example 1: Git Branch in Prompt (bashrc)

**File:** `git-prompt.bashrc`

```bash
#!/usr/bin/env bash
# git-prompt.bashrc - Shows current git branch in PS1

__git_branch() {
    git branch 2>/dev/null | grep '^*' | sed 's/* //'
}

# Add git branch to prompt
PS1='\u@\h:\w$(__git_branch | sed "s/./ (&)/")\$ '
```

### Example 2: Dangerous Command Warning (precommand)

**File:** `rm-warning.precommand`

```bash
#!/usr/bin/env bash
# rm-warning.precommand - Warns before dangerous rm commands

# Check if command starts with 'rm'
if [[ "$BASH_COMMAND" =~ ^rm.*\*.*$ ]]; then
    echo "⚠️  WARNING: You're about to rm with wildcards!"
    echo "Command: $BASH_COMMAND"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        # Cancel the command
        return 1
    fi
fi
```

### Example 3: Command Logger (postcommand)

**File:** `command-logger.postcommand`

```bash
#!/usr/bin/env bash
# command-logger.postcommand - Logs commands and execution time

LOG_FILE="$HOME/.command_history.log"

# Log the command with timestamp
echo "[$(date '+%Y-%m-%d %H:%M:%S')] $PWD: $BASH_COMMAND" >> "$LOG_FILE"

# Optional: Track command success/failure
if [[ $? -eq 0 ]]; then
    echo "  ✓ Success" >> "$LOG_FILE"
else
    echo "  ✗ Failed (exit code: $?)" >> "$LOG_FILE"
fi
```

### Example 4: Tmux Preview Pane (postcommand)

**File:** `tmux-preview.postcommand`

```bash
#!/usr/bin/env bash
# tmux-preview.postcommand - Auto-updates tmux preview pane

[[ -z "$TMUX" ]] && return 0

# Detect directory changes
if [[ "$PWD" != "${POTATO_PREV_PWD:-}" ]]; then
    export POTATO_PREV_PWD="$PWD"
    
    # Create preview pane if needed
    if [[ $(tmux list-panes | wc -l) -eq 1 ]]; then
        tmux split-window -h -d "cat"
    fi
    
    PREVIEW_PANE=$(tmux list-panes -F "#{pane_id}" | tail -1)
    
    # Show README or directory listing
    if [[ -f "README.md" ]]; then
        tmux respawn-pane -t "$PREVIEW_PANE" -k "cat README.md; cat"
    else
        tmux respawn-pane -t "$PREVIEW_PANE" -k "ls -lah; cat"
    fi
fi
```

## Available Variables in Toppings

### All Topping Types
- `$PWD` - Current directory
- `$HOME` - User home directory
- `$USER` - Username
- All standard bash variables

### Precommand & Postcommand Only
- `$BASH_COMMAND` - The command about to execute (precommand) or just executed (postcommand)
- `$?` - Exit code of last command (postcommand only)

### Custom Variables
You can create persistent variables by exporting them:

```bash
# In a .bashrc topping
export POTATO_MY_VARIABLE="value"

# Access in .precommand or .postcommand
echo $POTATO_MY_VARIABLE
```

## Best Practices

### 1. Keep Toppings Focused
Each topping should do one thing well. Don't create a massive topping that does everything.

❌ **Bad:** `everything.postcommand` (500 lines, does logging, git updates, notifications, etc.)  
✅ **Good:** Separate toppings for each feature

### 2. Handle Errors Gracefully
Always check if commands/tools exist before using them:

```bash
if command -v git &>/dev/null; then
    # Use git
fi
```

### 3. Use Return Codes Properly
- Return 0 for success
- Return 1 to cancel/fail (especially in precommand)
- Don't exit (it will close your shell!)

```bash
# In precommand
if [[ some_dangerous_condition ]]; then
    echo "Cancelling command"
    return 1  # ✓ Correct
    # exit 1  # ✗ Wrong - closes shell!
fi
```

### 4. Avoid Heavy Operations
Postcommand toppings run after **every** command. Keep them fast!

❌ **Bad:** Network calls, slow computations  
✅ **Good:** Quick checks, simple logging

### 5. Log for Debugging
When developing toppings, use a log file:

```bash
LOG="/tmp/my-topping.log"
echo "Debug: something happened" >> "$LOG"
```

### 6. Name Descriptively
Use clear, descriptive names:
- `git-prompt.bashrc` ✓
- `warn-rm.precommand` ✓
- `stuff.postcommand` ✗

## Real-World Example: Complete Workflow

Let's create a development environment setup:

**1. dev-env.bashrc** - Set up environment
```bash
#!/usr/bin/env bash
export DEV_ROOT="$HOME/projects"
export PATH="$PATH:$DEV_ROOT/bin"

alias proj='cd $DEV_ROOT'
```

**2. git-check.precommand** - Warn about committing to main
```bash
#!/usr/bin/env bash
if [[ "$BASH_COMMAND" =~ ^git\ commit ]]; then
    branch=$(git branch 2>/dev/null | grep '^*' | cut -d' ' -f2)
    if [[ "$branch" == "main" || "$branch" == "master" ]]; then
        echo "⚠️  You're committing to $branch!"
        read -p "Continue? (y/N): " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && return 1
    fi
fi
```

**3. project-tracker.postcommand** - Track time in projects
```bash
#!/usr/bin/env bash
TRACK_FILE="$HOME/.project_time.log"

if [[ "$PWD" != "${PREV_PROJECT_DIR:-}" ]]; then
    export PREV_PROJECT_DIR="$PWD"
    if [[ "$PWD" =~ ^$HOME/projects/ ]]; then
        project=$(basename "$PWD")
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Entered: $project" >> "$TRACK_FILE"
    fi
fi
```

Enable them all:
```bash
potato__ enable dev-env.bashrc
potato__ enable git-check.precommand
potato__ enable project-tracker.postcommand
source potato__ startup
```

## Troubleshooting

### My topping isn't running

1. **Check if it's enabled:**
   ```bash
   potato__ list
   ```

2. **Check the filename:** Must end with `.bashrc`, `.precommand`, or `.postcommand`

3. **Reload potato:**
   ```bash
   source potato__ startup
   ```

4. **Add debug logging:**
   ```bash
   echo "Topping executed at $(date)" >> /tmp/debug.log
   ```

### My postcommand is too slow

Postcommands run after every command. Profile them:
```bash
time source /path/to/topping.postcommand
```

Consider:
- Moving heavy work to background: `some_slow_task &`
- Caching results
- Only running on specific commands

### Variables aren't persisting

Export them in a `.bashrc` topping:
```bash
# In startup.bashrc
export MY_VAR="value"

# Now accessible in all toppings
echo $MY_VAR
```

## Dependencies

Potato requires:
- **bash** (4.0+)
- **undies** framework (must be in `$PATH`)

Optional but recommended:
- `bat` - Better file viewing
- `tree` - Directory visualization
- `jq` - JSON processing

## Installation

```bash
# Clone the repository
git clone https://github.com/pendashteh/potato.git
cd potato

# Add to your ~/.bashrc
echo 'export PATH="$PATH:'$(pwd)'"' >> ~/.bashrc
echo 'source potato__ startup' >> ~/.bashrc

# Reload
source ~/.bashrc
```

## Contributing

To contribute a topping:

1. Write your topping following the naming convention
2. Test it thoroughly
3. Add it to the `toppings/` directory
4. Document what it does and any dependencies
5. Submit a pull request

## Advanced Topics

### Topping Load Order

Toppings are loaded alphabetically within each type:
1. All `.bashrc` toppings (alphabetically)
2. `.precommand` toppings execute before each command (alphabetically)
3. `.postcommand` toppings execute after each command (alphabetically)

To control order, use numeric prefixes:
- `01-first.bashrc`
- `02-second.bashrc`
- `99-last.bashrc`

### Conditional Toppings

Enable toppings conditionally:

```bash
# In your .bashrc
if [[ "$HOSTNAME" == "work-laptop" ]]; then
    potato__ enable work-settings.bashrc
fi
```

### Topping Communication

Toppings can communicate via exported variables:

```bash
# In early.postcommand
export POTATO_COMMAND_COUNT=$((POTATO_COMMAND_COUNT + 1))

# In later.postcommand
if [[ $POTATO_COMMAND_COUNT -gt 100 ]]; then
    echo "You've run 100 commands!"
fi
```

## License

GPL-3.0 License

## Credits

Created by [pendashteh](https://github.com/pendashteh)

---

**Note:** This is a complete rewrite of the original potato. The old version is available in the `old` branch.
