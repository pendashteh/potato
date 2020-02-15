#!/usr/bin/env bash

. $POTATO_PATH/lib/potato.inc.sh

echo "It's a potato farm."

potato_source_all $HOME/.potato/enabled/*.bashrc
