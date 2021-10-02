export GIT_PS1_SHOWDIRTYSTATE=1
export GIT_PS1_SHOWCOLORHINTS=1
export GIT_PS1_SHOWUNTRACKEDFILES=1

typeset -F __git_ps1 >/dev/null || {
  if [ -e /usr/lib/git-core/git-sh-prompt ]; then
    # https://stackoverflow.com/a/55082075/257479
    source /usr/lib/git-core/git-sh-prompt
  else
    # https://stackoverflow.com/a/15398153/257479
    curl -L https://raw.github.com/git/git/master/contrib/completion/git-prompt.sh > $HOME/.git-prompt.sh
    source $HOME/.git-prompt.sh
  fi

}

export PS1='\[\033[36m\]\w\[\033[m\]\[\033[33;2m\]$(__git_ps1)\[\033[m\]> '

# Setting up a global gitignore properly.
# Source: https://stackoverflow.com/a/22885996/257479

mkdir -p $HOME/.config/git
touch $HOME/.config/git/ignore

: https://stackoverflow.com/a/22303923/257479
alias git-lost="git fsck --full --no-reflogs --unreachable --lost-found | grep commit | cut -d\  -f3 | xargs -n 1 git log -n 1 --pretty=oneline"
