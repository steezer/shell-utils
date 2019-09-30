#!/bin/bash

if [ -n "$@" ];then
	ldconfig -p | grep "$@" | awk -F "=>" '{system("ls -al "$2)}'
fi
