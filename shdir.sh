#!/bin/bash
#统计当前目录下的隐藏文件大小信息
ls -A | grep "^\..*$" | tr "\n" " " | xargs du -csh