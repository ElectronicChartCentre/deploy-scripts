#!/bin/bash

# 
# Arguments:
# 1) Jenkins job name. Like "gds-trunk-derby".
# 2) Instance name. "production", "customerA"...
# 3) Node number 0-99. Must be unique across applications, instances and servers
#

# read command line arguments
job=$1
instance=$2
node=`printf "%02i" $3`

# test arguments
if [ ! -n "${job}" ] || 
   [ ! -n "${instance}" ] ||
   [ ! -n "${node}" ]; then
  echo "Usage: $0 job instance node"
  exit -1
fi

# set up some variables
jar=$job-$instance.jar
dir=~/deploy/node${node}/
current=$dir/current
prev=$dir/prev

# create node directory
mkdir -p ${dir} ; cd ${dir}

# delete previous previous..
if [ -d $prev ]; then
  rm -rf $prev
fi

# stop current and move to previous
if [ -d $current ]; then
  (cd $current && bash control.sh stop $node)
  mv $current $prev
fi

# establish current and start
mkdir $current $current/logs
cp ~/tmp/{control.sh,$job-$instance*} $current/
(cd $current 
 echo "node="${node} > .defaults
 if [ -f $job-$instance.props ]; then
     cat $job-$instance.props >> .defaults
 fi
 bash control.sh start ${node})
