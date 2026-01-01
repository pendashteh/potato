# Potato - AI Coding Agent Guide

This guide helps AI coding assistants understand and work with the Potato bash extension framework.

## Quick Reference for AI Agents

### What is Potato?
A bash hook system that executes custom scripts ("toppings") at three lifecycle points:
1. Shell startup (`.bashrc`)
2. Before command execution (`.precommand`)
3. After command execution (`.postcommand`)

### Core Concepts

```
┌──────────────────────────────────────────────────┐
│ Topping Type │ Filename    │ Execution Trigger   │
├──────────────┼─────────────┼─────────────────────┤
│ Startup      │ *.bashrc    │ Shell initialization│
│ Pre-command  │ *.precommand│ Before each command │
│ Post-command │ *.postcommand│ After each command │
└──────────────────────────────────────────────────┘
```

## Creating Toppings - Decision Tree

When a user asks you to create potato functionality:

```
Is it a one-time setup? (aliases, env vars, PATH)
  YES → Create *.bashrc topping
  NO  ↓

Does it need to run BEFORE a command? (validation, warnings)
  YES → Create *.precommand topping
  NO  ↓

Does it need to run AFTER a command? (logging, notifications, state tracking)
  YES → Create *.postcommand topping
```

## Template Patterns

### Pattern 1: Basic .bashrc Topping

```bash
#!/usr/bin/env bash
# filename: descriptive-name.bashrc
# Purpose: One-line description

# Set environment variables
export MYVAR="value"

# Add to PATH
export PATH="$PATH:/custom/path"

# Define functions
my_function() {
    # Implementation
}

# Set aliases
alias myalias='command'
```

**When to use:** Setting up environment, aliases, functions that should always be available.

### Pattern 2: Command Validator (.precommand)

```bash
#!/usr/bin/env bash
# filename: validator-name.precommand
# Purpose: Validate/warn before command execution

# Check if command matches pattern
if [[ "$BASH_COMMAND" =~ pattern ]]; then
    # Warn user
    echo "⚠️  Warning message"
    
    # Optional: Ask for confirmation
    read -p "Continue? (y/N): " -n 1 -r
    echo
    
    # Return 1 to cancel the command
    [[ ! $REPLY =~ ^[Yy]$ ]] && return 1
fi

# Return 0 to allow command
return 0
```

**When to use:** Preventing dangerous operations, enforcing policies, command modification.

### Pattern 3: State Tracker (.postcommand)

```bash
#!/usr/bin/env bash
# filename: tracker-name.postcommand
# Purpose: Track state changes after commands

# Only run in specific conditions
[[ some_condition ]] || return 0

# Detect state changes
if [[ "$CURRENT_STATE" != "${PREVIOUS_STATE:-}" ]]; then
    export PREVIOUS_STATE="$CURRENT_STATE"
    
    # React to change
    perform_action
fi
```

**When to use:** Responding to directory changes, command results, environment changes.

### Pattern 4: Logger (.postcommand)

```bash
#!/usr/bin/env bash
# filename: logger-name.postcommand
# Purpose: Log command execution

LOG_FILE="$HOME/.command.log"

# Log with timestamp
echo "[$(date '+%Y-%m-%d %H:%M:%S')] $PWD: $BASH_COMMAND" >> "$LOG_FILE"

# Optional: Log exit status
[[ $? -eq 0 ]] && status="✓" || status="✗"
echo "  $status" >> "$LOG_FILE"
```

**When to use:** Command history tracking, audit trails, debugging.

## Common Variables Available

### Always Available
```bash
$PWD          # Current directory
$HOME         # User home
$USER         # Username
$BASH_VERSION # Bash version
```

### In precommand/postcommand
```bash
$BASH_COMMAND # Command being/just executed
$?            # Exit code (postcommand only)
```

### Custom State Variables
Export variables to share between toppings:
```bash
export POTATO_VARNAME="value"  # Prefix with POTATO_ to avoid conflicts
```

## Critical Rules for AI Agents

### ✅ DO

1. **Always return, never exit**
   ```bash
   return 1  # ✓ Stops command execution
   exit 1    # ✗ Closes the shell!
   ```

2. **Check command availability**
   ```bash
   if command -v tool &>/dev/null; then
       # Use tool
   fi
   ```

3. **Handle edge cases**
   ```bash
   [[ -z "$VAR" ]] && return 0  # Exit early if condition not met
   ```

4. **Use descriptive names**
   ```bash
   git-branch-prompt.bashrc      # ✓ Clear purpose
   stuff.postcommand             # ✗ Unclear
   ```

5. **Add comments**
   ```bash
   # Check if we're in a git repository
   [[ -d .git ]] || return 0
   ```

6. **Keep postcommands fast**
   ```bash
   # Fast operations only
   background_task &  # Run slow tasks in background
   ```

### ❌ DON'T

1. **Don't use exit in toppings** - Use `return` instead
2. **Don't assume tools exist** - Always check with `command -v`
3. **Don't make network calls in postcommand** - Too slow
4. **Don't forget error handling** - Check conditions
5. **Don't use generic names** - Be specific
6. **Don't modify $BASH_COMMAND** - Read-only

## Example Requests and Solutions

### Request: "Add git branch to my prompt"

**Solution:** Create `.bashrc` topping

```bash
#!/usr/bin/env bash
# git-prompt.bashrc

__git_branch() {
    git branch 2>/dev/null | grep '^*' | sed 's/* //'
}

PS1='\u@\h:\w$(__git_branch | sed "s/./ (&)/")\$ '
```

**Reasoning:** Prompt setup is one-time configuration → `.bashrc`

### Request: "Warn me before I delete everything"

**Solution:** Create `.precommand` topping

```bash
#!/usr/bin/env bash
# rm-warning.precommand

if [[ "$BASH_COMMAND" =~ ^rm.*\*.*$ ]]; then
    echo "⚠️  Dangerous rm with wildcards!"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && return 1
fi
```

**Reasoning:** Needs to intercept before execution → `.precommand`

### Request: "Track how much time I spend in each project"

**Solution:** Create `.postcommand` topping

```bash
#!/usr/bin/env bash
# project-timer.postcommand

if [[ "$PWD" != "${PREV_DIR:-}" ]]; then
    export PREV_DIR="$PWD"
    
    if [[ "$PWD" =~ /projects/([^/]+) ]]; then
        project="${BASH_REMATCH[1]}"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $project" >> ~/.project-time.log
    fi
fi
```

**Reasoning:** Reacts to directory changes after commands → `.postcommand`

### Request: "Auto-update tmux preview pane with README"

**Solution:** Create `.postcommand` + `.bashrc` helper

```bash
# tmux-preview.postcommand
#!/usr/bin/env bash

[[ -z "$TMUX" ]] && return 0

if [[ "$PWD" != "${POTATO_PREV_PWD:-}" ]]; then
    export POTATO_PREV_PWD="$PWD"
    
    # Create pane if needed
    if [[ $(tmux list-panes | wc -l) -eq 1 ]]; then
        tmux split-window -h -d "cat"
    fi
    
    PANE=$(tmux list-panes -F "#{pane_id}" | tail -1)
    
    if [[ -f README.md ]]; then
        tmux respawn-pane -t "$PANE" -k "cat README.md; cat"
    fi
fi
```

**Reasoning:** Reacts to directory changes + manages external tool (tmux) → `.postcommand`

## Debugging Toppings

When users report issues, add logging:

```bash
#!/usr/bin/env bash
# topping-name.postcommand

LOG="/tmp/topping-debug.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"
}

log "Topping started"
log "PWD: $PWD"
log "BASH_COMMAND: $BASH_COMMAND"

# ... rest of topping code ...

log "Topping completed"
```

Then ask user to:
```bash
rm /tmp/topping-debug.log
source potato__ startup
# reproduce issue
cat /tmp/topping-debug.log
```

## Testing Checklist

Before providing a topping to a user, verify:

- [ ] Filename follows `name.type` convention
- [ ] Uses `return` not `exit`
- [ ] Checks for required commands with `command -v`
- [ ] Has error handling for edge cases
- [ ] Includes comments explaining logic
- [ ] Fast enough for postcommand (if applicable)
- [ ] Doesn't pollute global namespace (uses functions or POTATO_ prefix)

## Integration Patterns

### Pattern: Condition-based Execution

```bash
# Run only in git repos
[[ -d .git ]] || return 0

# Run only in specific directories
[[ "$PWD" =~ ^$HOME/projects ]] || return 0

# Run only for specific commands
[[ "$BASH_COMMAND" =~ ^git\ commit ]] || return 0
```

### Pattern: State Persistence

```bash
# In .bashrc - Initialize
export POTATO_COUNTER=0

# In .postcommand - Increment
export POTATO_COUNTER=$((POTATO_COUNTER + 1))

# Use anywhere
echo "Commands run: $POTATO_COUNTER"
```

### Pattern: Performance Optimization

```bash
# Cache expensive operations
if [[ -z "$POTATO_GIT_STATUS" ]] || [[ "$PWD" != "$POTATO_LAST_PWD" ]]; then
    export POTATO_GIT_STATUS=$(git status --short 2>/dev/null)
    export POTATO_LAST_PWD="$PWD"
fi
```

## Common Pitfalls

1. **Forgetting to export variables**
   ```bash
   MYVAR="value"              # ✗ Not available to other toppings
   export MYVAR="value"       # ✓ Available everywhere
   ```

2. **Not handling missing commands**
   ```bash
   git status                 # ✗ Fails if not in git repo
   git status 2>/dev/null     # ✓ Silently fails
   ```

3. **Slow postcommand operations**
   ```bash
   curl https://api.com       # ✗ Blocks every command
   curl https://api.com &     # ✓ Runs in background
   ```

4. **Not checking state changes**
   ```bash
   # ✗ Runs every time, even if nothing changed
   update_preview
   
   # ✓ Only runs when directory changes
   [[ "$PWD" != "$PREV_PWD" ]] && update_preview
   ```

## Quick Command Reference

```bash
# List enabled toppings
potato__ list

# Enable a topping
potato__ enable /path/to/name.bashrc

# Disable a topping
potato__ disable name.bashrc

# Reload potato (after enabling/disabling)
source potato__ startup
```

## Summary for AI Agents

When asked to create potato functionality:

1. **Determine the type** - startup, precommand, or postcommand
2. **Use the appropriate template** - Match the pattern to the need
3. **Follow the rules** - return not exit, check commands exist, handle errors
4. **Name descriptively** - `feature-name.type`
5. **Add logging if complex** - Help with debugging
6. **Test mentally** - Walk through edge cases

The goal is to create focused, reliable, maintainable bash extensions that enhance the user's shell experience without compromising stability or performance.
