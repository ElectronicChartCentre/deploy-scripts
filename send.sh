#!/bin/bash

#
# Arguments:
# 1) Jenkins job name. Like "project-master".
# 2) Instance name. "production", "customerA"...
# 3) username@host 
#

# read command line arguments
job=$1
instance=$2
userhost=$3

# the jenkins archive directory for the job
jdir=${JENKINS_HOME}/jobs/$job/lastStable/archive/

# copy single jar if present. typically with embedded jetty.
if [ -f $jdir/target/$instance-*.jar ]; then
  scp $jdir/target/$instance-*.jar $userhost:tmp/$job-$instance.jar
  scp upgrade.sh $userhost:tmp/
  scp control.sh $userhost:tmp/
fi

# copy instance properties and other extra files if present
for extrafile in `ls -1 ${job}-${instance}* 2>/dev/null`; do
  scp $extrafile $userhost:tmp/
done
