#!/usr/bin/env bash

# Sets potato_root passed by .bashrc
potato_root=$POTATO_PATH

. $POTATO_PATH/lib/potato.inc.sh

echo "It's a potato farm."

potato_source_all $HOME/.potato/enabled/*.bashrc
