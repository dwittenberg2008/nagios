#!/bin/bash

# Simple shell script to delete a host comment if you know
# the comment ID
# Daniel Wittenberg <dwittenberg2008@gmail.com>

PRINTF="/usr/bin/printf"
NOW=`date +%s`
CMNDFILE='/var/nagios/rw/nagios.cmd'

COMMENT=$1

if [ "$COMMENT"X == "X" ]; then
   echo "Usage: $0 <commentID>"
   echo ""
   exit
fi

$PRINTF "[%lu] DEL_HOST_COMMENT;$COMMENT\n" $NOW > $CMNDFILE
