# potato

## History
This software is re-written from scratch. The original `potato` can be found in `old` branch:
https://github.com/pendashteh/potato/tree/old

The functionality is split in two parts:
- A bash extender and toolkit (current)
- A framework for writing software in bash, called fullstop.

## Toppings

The main feature of potato is the introduction to the concept of **toppings**.

Toppings are bash snippets that can be loaded at various events:
1. When shell is loaded
2. Before a command is executed
3. After a command is executed

Examples:

`git-prompt.bashrc` can load with .bashrc to add git status to PS1

`rm-warning.precommand` can check if the command is set to `rm *` and warn the user first.

`command-log.postcommand` can capture stats about a command and record it after the command finishes execution.

## Install

The magic of `potato` is done via `potato startup` that should be sourced when bash is initiated.

Example:
```
export PATH="$PATH:/path/to/potato-dir"
source potato__ startup
```
This way, all `toppings` are loaded at startup and you can run potato globally as `potato__`

## Usage

Listing toppings:
```bash
potato__ list # Lists enabled toppings
```

Adding a bashrc topping:
```bash
potato__ enable ./git-prompt.bashrc # Sets the script to load with .bashrc
```
The file name should follow this naming convention:
- NAME.bashrc (for bashrc hooks)
- NAME.precommand
- NAME.postcommand

Disabling a topping:
```bash
potato__ disable ./git-prompt.bashrc # Unsets the script from loading with .bashrc
```

## Dependencies

This app is using `undies` framework. You must have it in $PATH.

