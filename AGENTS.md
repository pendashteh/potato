
# AGENTS.md

## Project Overview

Potato is a bash extension framework that executes custom scripts ("toppings") at shell lifecycle points. Toppings are bash scripts with specific filename suffixes that determine when they run.

## Topping Types

| Filename Pattern | Execution Point | Purpose |
|-----------------|-----------------|---------|
| `name.bashrc` | Shell startup | Environment setup, aliases, functions |
| `name.precommand` | Before each command | Validation, warnings, command interception |
| `name.postcommand` | After each command | Logging, state tracking, notifications |

## Setup Commands

```bash
# Enable a topping
potato__ enable /path/to/topping.bashrc

# Disable a topping
potato__ disable topping.bashrc

# List enabled toppings
potato__ list

# Reload after changes
source potato__ startup
```

## Creating Toppings

### Filename Convention
**CRITICAL**: Filename MUST match pattern: `descriptive-name.{bashrc|precommand|postcommand}`

### Available Variables
- `$PWD` - Current directory
- `$BASH_COMMAND` - Command being/just executed (in precommand/postcommand)
- `$?` - Exit code (in postcommand only)
- Custom: `export POTATO_VARNAME="value"` for state sharing

### Critical Rules

1. **Use `return` not `exit`**
   ```bash
   return 1  # ✓ Correct - stops execution
   exit 1    # ✗ Wrong - closes the shell
   ```

2. **Check command availability**
   ```bash
   command -v tool &>/dev/null || return 0
   ```

3. **Keep postcommands fast** - They run after EVERY command
   ```bash
   slow_operation &  # Run in background
   ```

4. **Track state changes efficiently**
   ```bash
   # Detect directory changes
   if [[ "$PWD" != "${POTATO_PREV_PWD:-}" ]]; then
       export POTATO_PREV_PWD="$PWD"
       # React to change
   fi
   ```

## Code Style

- Prefix exported variables with `POTATO_` to avoid conflicts
- Add comments explaining non-obvious logic
- Handle errors gracefully with early returns
- Use descriptive filenames: `git-prompt.bashrc` not `stuff.bashrc`

## Testing Approach

Add logging for debugging:
```bash
LOG="/tmp/topping-debug.log"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Debug info" >> "$LOG"
```

Then: `cat /tmp/topping-debug.log` to diagnose issues

## Common Patterns

### Pattern: bashrc topping
```bash
#!/usr/bin/env bash
# name.bashrc - Description
export MYVAR="value"
alias myalias='command'
```

### Pattern: precommand validation
```bash
#!/usr/bin/env bash
# name.precommand - Description
[[ "$BASH_COMMAND" =~ pattern ]] || return 0
echo "⚠️  Warning"
read -p "Continue? (y/N): " -n 1 -r
[[ ! $REPLY =~ ^[Yy]$ ]] && return 1
```

### Pattern: postcommand state tracker
```bash
#!/usr/bin/env bash
# name.postcommand - Description
[[ condition ]] || return 0
if [[ "$STATE" != "${PREV_STATE:-}" ]]; then
    export PREV_STATE="$STATE"
    # React to change
fi
```

## Dependencies

- bash 4.0+
- undies framework (must be in $PATH)

## Project Structure

```
potato/
├── potato__           # Main executable
├── toppings/          # Example toppings
├── README.md          # User-facing documentation
├── DEVELOPERS.md      # Comprehensive developer guide
└── AGENTS.md          # This file
```

## Common Gotchas

- Topping not running? Check filename ends with correct suffix
- Shell closing unexpectedly? You used `exit` instead of `return`
- Slow prompt? Postcommand doing heavy work - move to background
- Variables not persisting? Export them in a `.bashrc` topping
- Command not captured? Potato uses DEBUG trap internally
