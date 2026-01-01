
**Version:** 2.0  
**Date:** January 2026  
**Status:** Design Phase

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Core Architecture](#core-architecture)
3. [File Format Specification](#file-format-specification)
4. [DSL Language Design](#dsl-language-design)
5. [Compilation System](#compilation-system)
6. [Hook System](#hook-system)
7. [State Management](#state-management)
8. [Conflict Detection](#conflict-detection)
9. [Registry & Distribution](#registry--distribution)
10. [Tooling & Commands](#tooling--commands)
11. [Use Cases & Examples](#use-cases--examples)
12. [Implementation Phases](#implementation-phases)
13. [Inspiration & Prior Art](#inspiration--prior-art)
14. [Future Considerations](#future-considerations)

---

## Executive Summary

Potato is a bash extension framework that executes custom scripts ("toppings") at shell lifecycle points. This document outlines the evolution from simple bash hooks to a structured, declarative system while maintaining backward compatibility and simplicity.

### Core Philosophy

- **Simplicity First**: Like Git hooks - bash scripts in directories
- **Progressive Enhancement**: Optional structure for those who need it
- **Dual Format**: `.topping` (declarative DSL) compiles to `.sh` (bash scripts)
- **TypeScript-like Model**: `.topping` → `.sh` similar to `.ts` → `.js`
- **No Magic**: Always expose the compiled bash layer

### Key Design Decisions

1. **Filename convention**: `name.{bashrc,precommand,postcommand}.sh`
2. **Optional DSL**: `name.topping` compiles to `name.{type}.sh`
3. **Bash as runtime**: Everything runs as bash underneath
4. **Git Hooks simplicity**: Start simple, add structure as needed
5. **Systemd-inspired metadata**: Optional structured configuration

---

## Core Architecture

### Execution Flow

```
User types command
        ↓
┌───────────────────────┐
│ precommand.sh hooks   │ ← Can abort command
└───────────────────────┘
        ↓
┌───────────────────────┐
│ Command executes      │
└───────────────────────┘
        ↓
┌───────────────────────┐
│ postcommand.sh hooks  │ ← React to results
└───────────────────────┘
```

### Directory Structure

```
~/.potato/
├── config                      # Global configuration
├── toppings-available/
│   ├── git-prompt.bashrc.sh
│   ├── npm-auto.postcommand.sh
│   └── aws-safety.topping      # Source DSL
├── toppings-enabled/           # Symlinks (systemd-style)
│   └── git-prompt.bashrc.sh -> ../toppings-available/git-prompt.bashrc.sh
├── compiled/                   # Compiled from .topping
│   └── aws-safety.precommand.sh
└── cache/                      # State, hashes, etc.
    └── file-hashes/
```

### XDG Base Directory Compliance

```bash
# Config
~/.config/potato/config
~/.config/potato/toppings/

# Data/State
~/.local/share/potato/enabled/
~/.local/share/potato/cache/

# Cache
~/.cache/potato/file-hashes/
```

---

## File Format Specification

### Bash Scripts (.sh files)

**Format**: Standard bash scripts with optional metadata comments

```bash
#!/usr/bin/env bash
# POTATO_NAME: npm-auto-install
# POTATO_VERSION: 1.0.0
# POTATO_DESCRIPTION: Auto-install npm packages when package.json changes
# POTATO_AUTHOR: npmjs
# POTATO_CONFLICTS: yarn-auto-install, pnpm-auto-install
# POTATO_REQUIRES: npm
# POTATO_TRIGGERS: file_changed(package.json)
# POTATO_PRIORITY: 50
# POTATO_ASYNC: false

# Actual bash code
[[ -f package.json ]] || return 0

if potato_on_file_changed package.json; then
    npm install
fi
```

**Naming Convention**:
- `name.bashrc.sh` - Runs once at shell startup
- `name.precommand.sh` - Runs before each command
- `name.postcommand.sh` - Runs after each command

### DSL Files (.topping files)

**Format**: INI-like declarative syntax (systemd-inspired)

```ini
[Topping]
Name=npm-auto-install
Version=1.0.0
Description=Auto-install npm packages when package.json changes
Author=npmjs
Conflicts=yarn-auto-install pnpm-auto-install
Requires=npm
Priority=50

[Trigger]
Type=postcommand
On=file_changed package.json
On=file_changed package-lock.json
Condition=file_exists package.json

[Action]
Run=npm install
RunIf=npm outdated --parseable | grep -q .
Silent=false
Background=false
```

**Compiles to**: `npm-auto-install.postcommand.sh`

---

## DSL Language Design

### Section: [Topping]

Metadata about the topping.

```ini
[Topping]
Name=string                    # Unique identifier
Version=semver                 # Semantic version
Description=string             # Human-readable description
Author=string                  # Author name or email
Homepage=url                   # Documentation URL
License=string                 # License identifier
Conflicts=list                 # Space-separated conflicting toppings
Requires=list                  # Required commands/tools
Before=list                    # Must run before these toppings
After=list                     # Must run after these toppings
Priority=integer               # 0-100, higher runs first
```

### Section: [Trigger]

When the topping should execute.

```ini
[Trigger]
Type=bashrc|precommand|postcommand

# File-based triggers
On=file_exists <path>          # File exists in $PWD
On=file_missing <path>         # File doesn't exist
On=file_changed <path>         # File modified since last check
On=file_older <path> <days>    # File older than N days
On=file_newer <path1> <path2>  # File1 is newer than file2

# Directory triggers
On=dir_entered <pattern>       # Entered directory matching pattern
On=dir_exited <pattern>        # Exited directory matching pattern
On=dir_contains <pattern>      # Current dir contains files matching pattern

# Command triggers (precommand/postcommand only)
On=command <regex>             # Command matches regex
On=command_failed <regex>      # Command failed (postcommand only)
On=command_succeeded <regex>   # Command succeeded (postcommand only)

# Environment triggers
On=env_set <VAR>               # Environment variable is set
On=env_equals <VAR> <value>    # Env var equals value
On=env_matches <VAR> <regex>   # Env var matches regex

# Time-based triggers
On=time_after HH:MM            # After time of day
On=time_before HH:MM           # Before time of day
On=weekday Mon,Tue,Wed         # Specific days of week

# Composite triggers
All                            # All On= conditions must match (AND)
Any                            # Any On= condition matches (OR)
Not=<trigger>                  # Negate a trigger

# Additional conditions
Condition=<bash expression>    # Raw bash condition (escape hatch)
```

### Section: [Action]

What to do when triggered.

```ini
[Action]
# Execution
Run=<command>                  # Execute command
RunSilent=<command>            # Execute, suppress output
RunBackground=<command>        # Execute in background
RunIf=<condition>              # Only run if condition true

# User interaction
Warn=<message>                 # Print warning to stderr
Confirm=<message>              # Ask for confirmation
ConfirmMatch=<pattern>         # Require specific input
Abort                          # Cancel command (precommand only)
AbortIf=<condition>            # Conditional abort

# Logging
Log=<message>                  # Log to potato log
LogLevel=info|warn|error       # Log level

# State management
Set=<VAR> <value>              # Set environment variable
Unset=<VAR>                    # Unset environment variable
Touch=<path>                   # Create marker file
Remove=<path>                  # Remove marker file

# Control flow
Skip                           # Skip this topping execution
SkipIf=<condition>             # Conditional skip
```

### DSL Examples

#### Example 1: Simple file watcher
```ini
[Topping]
Name=readme-viewer
Description=Show README when entering directory

[Trigger]
Type=postcommand
On=dir_entered *
On=file_exists README.md

[Action]
Run=cat README.md
```

#### Example 2: Safety check with confirmation
```ini
[Topping]
Name=aws-production-safety
Description=Prevent accidental production deletions

[Trigger]
Type=precommand
On=command ^aws.*delete
On=env_equals AWS_PROFILE production
All

[Action]
Warn=⚠️  You are about to DELETE in PRODUCTION!
Confirm=Type 'DELETE' to continue
ConfirmMatch=DELETE
AbortIf=!confirmed
```

#### Example 3: Complex workflow
```ini
[Topping]
Name=docker-dev-helper
Description=Auto-manage Docker development environment

[Trigger]
Type=postcommand
On=dir_entered */project-*
On=file_exists docker-compose.yml
On=command docker-compose up
All

[Action]
Log=Starting development environment
Run=docker-compose up -d
RunIf=! docker-compose ps | grep -q Up
Warn=Development environment is now running
Set=DEV_RUNNING true
```

---

## Compilation System

### Compiler Architecture

```
┌─────────────────┐
│  name.topping   │
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│  Parser         │  Parse INI format
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│  Validator      │  Check syntax, dependencies
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│  Code Generator │  Generate bash code
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│  name.{type}.sh │  Compiled bash script
└─────────────────┘
```

### Compilation Process

```bash
potato__ compile name.topping
```

**Steps:**

1. **Parse**: Read .topping file, parse INI sections
2. **Validate**: Check syntax, verify dependencies exist
3. **Generate**: Create bash script with equivalent logic
4. **Add metadata**: Include original .topping as comments
5. **Make executable**: chmod +x
6. **Link**: Create symlink in enabled/ if needed

### Generated Code Structure

```bash
#!/usr/bin/env bash
# AUTO-GENERATED from npm-auto-install.topping
# DO NOT EDIT - Changes will be overwritten
# Regenerate with: potato__ compile npm-auto-install.topping
#
# POTATO_NAME: npm-auto-install
# POTATO_VERSION: 1.0.0
# POTATO_SOURCE: npm-auto-install.topping
# POTATO_COMPILED_AT: 2026-01-01T12:00:00Z

# Generated condition checks
[[ -f "package.json" ]] || return 0

# Check file changed
_HASH_FILE="/tmp/potato-hash-$(echo "$PWD/package.json" | md5sum | cut -d' ' -f1)"
_CURRENT_HASH=$(md5sum "package.json" 2>/dev/null | cut -d' ' -f1)
_PREV_HASH=$(cat "$_HASH_FILE" 2>/dev/null)

if [[ "$_CURRENT_HASH" != "$_PREV_HASH" ]]; then
    echo "$_CURRENT_HASH" > "$_HASH_FILE"
    
    # Generated action
    npm install
fi
```

### Recompilation

```bash
# Auto-recompile on changes
potato__ watch name.topping

# Recompile all
potato__ compile --all

# Check if recompilation needed
potato__ check
```

---

## Hook System

### Current Hooks (Implemented)

1. **bashrc** - Shell startup
2. **precommand** - Before each command (via DEBUG trap)
3. **postcommand** - After each command (via DEBUG trap + PROMPT_COMMAND)

### Proposed Additional Hooks

#### High Value, Low Complexity

```bash
# Directory change hook (special case of postcommand)
on_directory_change.sh
# Triggered only when $PWD changes

# Exit hook
on_exit.sh
# Runs when shell exits (via trap EXIT)

# Error hook
on_error.sh
# Runs when command fails (check $? in postcommand)
```

#### Medium Value, Medium Complexity

```bash
# Command not found
on_command_not_found.sh
# Override command_not_found_handle function

# Background job completion
on_job_done.sh
# Trigger when background job finishes
```

#### Low Priority (Complex, Edge Cases)

```bash
# Specific command hooks
on_git_commit.sh
on_npm_install.sh
# Would require parsing $BASH_COMMAND - fragile

# Periodic hooks
on_every_5min.sh
# Would require background timer process
```

### Hook Implementation Strategy

**Phase 1**: Keep current three hooks (bashrc, precommand, postcommand)

**Phase 2**: Add directory_change as special postcommand optimization
```bash
# Built into potato framework
if [[ "$PWD" != "${POTATO_PREV_PWD:-}" ]]; then
    export POTATO_PREV_PWD="$PWD"
    # Run *.directory_change.sh hooks
fi
```

**Phase 3**: Add exit and error hooks (via bash traps)

---

## State Management

### Current Approach

Ad-hoc exported variables:
```bash
export POTATO_PREV_PWD="$PWD"
export POTATO_LAST_COMMAND="$BASH_COMMAND"
```

### Proposed State API

```bash
# Set state (persists across commands)
potato_state_set KEY VALUE

# Get state
potato_state_get KEY

# Delete state
potato_state_del KEY

# Check if state exists
potato_state_has KEY

# Implementation uses namespaced env vars
# POTATO_STATE_KEY=VALUE
```

### File State (Hashes, Timestamps)

```bash
# Check if file changed
potato_on_file_changed FILE

# Implementation:
# - Stores MD5 hash in ~/.cache/potato/file-hashes/
# - Compares current vs previous
# - Returns 0 if changed, 1 if same
```

### Persistent State

```bash
# Store data across shell sessions
potato_persist_set KEY VALUE
# Writes to ~/.local/share/potato/state/KEY

potato_persist_get KEY
# Reads from ~/.local/share/potato/state/KEY
```

---

## Conflict Detection

### Detection Methods

#### 1. Metadata-based (from .topping or # comments)

```bash
# POTATO_CONFLICTS: yarn-auto-install, pnpm-auto-install
```

Potato parses this and warns if multiple conflicting toppings enabled.

#### 2. Trigger overlap detection

```bash
potato__ conflicts
```

Analyzes all enabled toppings:
- Same trigger conditions
- Same files being watched
- Same commands being intercepted

#### 3. Priority conflicts

Multiple toppings with same priority on same trigger → Warning

### Conflict Resolution

```ini
# In .topping file
[Topping]
Conflicts=other-topping
Priority=60  # Higher priority wins
```

Or manual:
```bash
potato__ disable conflicting-topping
```

### Inspection Tools

```bash
# Show what will run
potato__ inspect

# Show conflicts
potato__ conflicts

# Show trigger analysis
potato__ triggers

# Dry run
POTATO_DRY_RUN=1 command
```

---

## Registry & Distribution

### Inspiration from Existing Ecosystems

| Feature | Homebrew | npm | apt | GitHub Actions | Systemd |
|---------|----------|-----|-----|----------------|---------|
| Central registry | ✓ | ✓ | ✓ | ✓ | ✗ |
| Versioning | ✓ | ✓ | ✓ | ✓ | ✗ |
| Dependencies | ✓ | ✓ | ✓ | ✗ | ✓ |
| Conflicts | ✓ | ✗ | ✓ | ✗ | ✓ |
| Search | ✓ | ✓ | ✓ | ✓ | ✗ |
| Community | taps | registry | PPAs | marketplace | ✗ |

### Proposed Registry Model

**Primary**: GitHub as registry (like Homebrew taps)

```bash
# Add registry
potato__ tap add user/repo

# Install from registry
potato__ install aws-safety
# Fetches from default registry

# Install from specific tap
potato__ install user/repo/custom-topping

# Install from URL
potato__ install https://github.com/user/repo/toppings/name.topping

# Version pinning
potato__ install aws-safety@1.2.0
potato__ install aws-safety@latest
```

### Registry Structure (GitHub-based)

```
github.com/potato-toppings/official/
├── README.md
├── index.json                 # Topping index
└── toppings/
    ├── aws-safety/
    │   ├── 1.0.0.topping
    │   ├── 1.1.0.topping
    │   ├── latest.topping -> 1.1.0.topping
    │   └── README.md
    └── npm-auto-install/
        └── ...
```

### index.json Format

```json
{
  "toppings": [
    {
      "name": "aws-safety",
      "description": "Prevent accidental AWS production deletions",
      "author": "potato-team",
      "homepage": "https://github.com/potato-toppings/official",
      "latest_version": "1.1.0",
      "versions": ["1.0.0", "1.1.0"],
      "requires": ["aws"],
      "conflicts": [],
      "downloads": 1234,
      "stars": 56
    }
  ]
}
```

### Installation Flow

```bash
potato__ install aws-safety
```

1. Check enabled taps
2. Search for `aws-safety` in tap indexes
3. Download `aws-safety/latest.topping`
4. Compile to `aws-safety.{type}.sh`
5. Place in `toppings-available/`
6. Ask user to enable: `potato__ enable aws-safety`

### Community Taps

```bash
# Official tap (default)
potato__ tap add potato/official

# Community taps
potato__ tap add aws-users/aws-toppings
potato__ tap add docker-fans/docker-helpers

# List taps
potato__ tap list

# Update tap indexes
potato__ tap update
```

---

## Tooling & Commands

### Core Commands

```bash
# Topping management
potato__ enable <topping>       # Enable a topping
potato__ disable <topping>      # Disable a topping
potato__ list                   # List enabled toppings
potato__ list --all             # List all available toppings

# Compilation
potato__ compile <topping>      # Compile .topping to .sh
potato__ compile --all          # Recompile all .topping files
potato__ watch <topping>        # Auto-recompile on changes
potato__ check                  # Check if recompilation needed

# Registry
potato__ tap add <url>          # Add topping registry
potato__ tap list               # List registries
potato__ tap update             # Update registry indexes
potato__ install <topping>      # Install from registry
potato__ uninstall <topping>    # Remove topping
potato__ search <query>         # Search registries
potato__ info <topping>         # Show topping information
potato__ upgrade                # Update all installed toppings

# Inspection
potato__ inspect                # Show what hooks are active
potato__ conflicts              # Detect conflicting toppings
potato__ triggers               # Show trigger analysis
potato__ status <topping>       # Show topping status
potato__ logs <topping>         # Show topping logs

# Debugging
potato__ test <topping>         # Test a topping
potato__ debug <topping>        # Run with debug output
potato__ trace                  # Trace hook execution

# Utilities
potato__ reload                 # Reload all toppings
potato__ validate <topping>     # Validate syntax
potato__ convert <old>          # Convert old format to new
```

### Inspection Output Examples

```bash
$ potato__ inspect

Active Toppings (3 enabled):
============================

[bashrc] - Runs at shell startup
  1. git-prompt (priority: 50)
     Description: Show git branch in prompt
     Source: git-prompt.bashrc.sh
     Status: ✓ Loaded

[precommand] - Runs before each command
  1. aws-safety (priority: 10)
     Description: Prevent AWS production deletions
     Source: aws-safety.topping → aws-safety.precommand.sh
     Compiled: 2026-01-01 12:00
     Triggers: command(^aws.*delete) AND env(AWS_PROFILE=production)
     Actions: warn, confirm, abort
     Status: ✓ Active

[postcommand] - Runs after each command
  1. npm-auto-install (priority: 50)
     Description: Auto-install npm packages
     Source: npm-auto-install.topping → npm-auto-install.postcommand.sh
     Compiled: 2026-01-01 11:00
     Triggers: file_changed(package.json)
     Actions: run(npm install)
     Status: ✓ Active
     ⚠️  Conflicts with: yarn-auto-install (disabled)

$ potato__ conflicts

Potential Conflicts:
===================

package.json monitoring:
  - npm-auto-install (enabled)
  - yarn-auto-install (disabled)
  → OK: Only one enabled

No active conflicts detected.
```

### Dry-run Mode

```bash
$ POTATO_DRY_RUN=1 cd /project

[DRY RUN] Hooks that would execute:
====================================

[postcommand]
  1. npm-auto-install
     Trigger matched: file_changed(package.json)
     Would run: npm install

  2. nvm-auto-switch
     Trigger matched: file_exists(.nvmrc)
     Would run: nvm use

$ POTATO_DRY_RUN=1 git push

[DRY RUN] Hooks that would execute:
====================================

[precommand]
  1. git-push-checklist
     Trigger matched: command(^git push)
     Would show: confirmation dialog
     User action required: yes/no
```

---

## Use Cases & Examples

### 1. Package Manager Auto-Install

**Scenario**: Automatically install dependencies when package files change

```ini
[Topping]
Name=npm-auto-install
Description=Auto-install npm packages when package.json changes
Requires=npm
Conflicts=yarn-auto-install pnpm-auto-install

[Trigger]
Type=postcommand
On=file_changed package.json
On=file_changed package-lock.json

[Action]
Run=npm install
Log=Installed npm packages
```

### 2. Cloud CLI Safety

**Scenario**: Prevent accidental production deletions

```ini
[Topping]
Name=aws-production-safety
Description=Require confirmation for AWS deletions in production
Requires=aws

[Trigger]
Type=precommand
On=command ^aws.*delete
On=env_equals AWS_PROFILE production
All

[Action]
Warn=⚠️  You are about to DELETE in PRODUCTION!
Confirm=Type 'DELETE' to continue
ConfirmMatch=DELETE
Abort
```

### 3. Development Environment Auto-Setup

**Scenario**: Auto-switch Node version when entering project

```ini
[Topping]
Name=nvm-auto-switch
Description=Auto-switch Node version based on .nvmrc
Requires=nvm

[Trigger]
Type=postcommand
On=dir_entered *
On=file_exists .nvmrc

[Action]
Run=nvm use
Silent=true
```

### 4. Git Workflow Helpers

**Scenario**: Remind about PR checklist before pushing

```ini
[Topping]
Name=git-pr-checklist
Description=Show PR checklist before git push
Priority=10

[Trigger]
Type=precommand
On=command ^git push

[Action]
Warn=📋 Pre-push checklist:
Warn=  - Tests passing?
Warn=  - Docs updated?
Warn=  - No debug code?
Confirm=Ready to push?
AbortIf=!confirmed
```

### 5. Docker Environment Management

**Scenario**: Auto-cleanup stopped containers

```ini
[Topping]
Name=docker-auto-cleanup
Description=Cleanup stopped containers after docker stop
Requires=docker

[Trigger]
Type=postcommand
On=command ^docker (stop|kill)

[Action]
RunBackground=docker container prune -f
Log=Cleaned up stopped containers
```

### 6. Time Tracking

**Scenario**: Automatically track time spent in projects

```ini
[Topping]
Name=project-time-tracker
Description=Track time spent in project directories

[Trigger]
Type=postcommand
On=dir_entered */projects/*

[Action]
Set=PROJECT_START_TIME $(date +%s)
Log=Started working on project: $PWD

[Trigger]
Type=postcommand
On=dir_exited */projects/*

[Action]
Run=echo "Time spent: $(($(date +%s) - $PROJECT_START_TIME))s" >> ~/.work-log
Unset=PROJECT_START_TIME
```

### 7. Security & Compliance

**Scenario**: Log all database connections for audit

```ini
[Topping]
Name=db-audit-logger
Description=Log database connections for compliance

[Trigger]
Type=postcommand
On=command ^(psql|mysql|mongo)

[Action]
Log=DB Connection: $BASH_COMMAND
Run=echo "[$(date)] $USER: $BASH_COMMAND" >> /var/log/db-audit.log
```

### 8. Tmux Preview Pane (Real Implementation)

**Scenario**: Auto-update tmux preview pane with README

```bash
#!/usr/bin/env bash
# tmux-preview.postcommand.sh
# POTATO_NAME: tmux-preview
# POTATO_DESCRIPTION: Auto-update tmux preview pane with file content
# POTATO_REQUIRES: tmux

[[ -z "$TMUX" ]] && return 0

# Detect directory change
if [[ "$PWD" != "${POTATO_PREV_PWD:-}" ]]; then
    export POTATO_PREV_PWD="$PWD"
    
    # Ensure preview pane exists
    if [[ $(tmux list-panes | wc -l) -eq 1 ]]; then
        tmux split-window -h -d "cat"
    fi
    
    PANE=$(tmux list-panes -F "#{pane_id}" | tail -1)
    
    # Show README or directory listing
    if [[ -f README.md ]]; then
        tmux respawn-pane -t "$PANE" -k "cat README.md; cat"
    else
        tmux respawn-pane -t "$PANE" -k "ls -lah; cat"
    fi
fi
```

---

## Implementation Phases

### Phase 1: Foundation (MVP) - 2-4 weeks

**Goal**: Ship working system with bash scripts

**Features**:
- ✅ Current `.bashrc`, `.precommand`, `.postcommand` system
- ✅ Basic enable/disable via symlinks
- ✅ `potato__ list` command
- ✅ Helper functions (e.g., `potato_on_file_changed`)
- ✅ Documentation with examples

**Deliverables**:
- Working potato framework
- 5-10 example toppings
- README.md, AGENTS.md, DEVELOPERS.md
- Installation script

### Phase 2: Structure (Optional Metadata) - 2-3 weeks

**Goal**: Add metadata without breaking existing toppings

**Features**:
- Parse comment-based metadata (`# POTATO_*`)
- `potato__ inspect` command
- `potato__ conflicts` detection
- Priority system
- Dependency checking

**Deliverables**:
- Metadata parser
- Inspection tools
- Conflict detection
- Updated documentation

### Phase 3: DSL & Compilation - 3-4 weeks

**Goal**: Add `.topping` format that compiles to `.sh`

**Features**:
- INI parser for `.topping` files
- Bash code generator
- `potato__ compile` command
- Auto-recompilation on changes
- Source tracking (which .topping generated which .sh)

**Deliverables**:
- Compiler implementation
- 10+ .topping examples
- Compilation documentation
- Migration guide

### Phase 4: Registry & Distribution - 4-6 weeks

**Goal**: Enable sharing and discovery

**Features**:
- Registry system (GitHub-based)
- `potato__ tap` commands
- `potato__ install`/`uninstall`
- `potato__ search`
- Version management
- Official topping repository

**Deliverables**:
- Registry infrastructure
- Official toppings repo
- Installation system
- Search functionality

### Phase 5: Advanced Features - Ongoing

**Goal**: Polish and advanced capabilities

**Features**:
- Additional hooks (directory_change, on_exit)
- State management API
- Async/background execution
- Testing framework
- Web-based topping browser
- IDE integration

**Deliverables**:
- Enhanced hook system
- State API
- Testing tools
- Community tools

---

## Inspiration & Prior Art

### Systems That Influenced Potato

#### 1. Git Hooks
**What we borrowed:**
- Simplicity: bash scripts in a directory
- Naming convention by lifecycle event
- Per-project vs global
- Skip mechanism

**Link**: https://git-scm.com/docs/githooks

#### 2. Systemd Units
**What we borrowed:**
- INI-like configuration format
- `Before=`/`After=` ordering
- `Conflicts=`/`Requires=` dependencies
- Enable/disable via symlinks
- Rich metadata

**Link**: https://systemd.io

#### 3. Homebrew
**What we borrowed:**
- Tap system for registries
- Formula structure
- `depends_on`/`conflicts_with`
- Community model
- Version management

**Link**: https://brew.sh

#### 4. GitHub Actions
**What we borrowed:**
- Event-driven triggers (`on:`)
- Marketplace for sharing
- YAML declarative syntax
- Conditional execution

**Link**: https://github.com/features/actions

#### 5. bash-preexec
**What we borrowed:**
- Hook concept for bash
- preexec/precmd pattern
- Using DEBUG trap

**Link**: https://github.com/rcaloras/bash-preexec

#### 6. direnv
**What we borrowed:**
- Directory-specific configuration
- `.envrc` pattern
- Auto-loading on directory change

**Link**: https://direnv.net

#### 7. Docker / Docker Compose
**What we borrowed:**
- DSL that generates runtime config
