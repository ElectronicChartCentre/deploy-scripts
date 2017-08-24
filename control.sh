#!/bin/sh

if [ ''$USER == 'root' ]; then
   echo "This script must not be run as root" 1>&2
   exit 1
fi

# $1: start/stop/watch
# $2: [nn]

# default values
port=8080
httpsPort=8443
stopkey=secret-default
runlog=logs/runlog

# make logs directory of not present
if [ ! -d logs ]; then
    mkdir logs
fi

# read defaults from file
if [ -f .defaults ]; then
  . .defaults
fi

# read command line argument if present
if [ -n "$2" ]; then
  node=$2
fi

# node with value "01"-"99" to control multinode setup
if [ -n "$node" ] && [ "$node" -gt 0 ] && [ "$node" -lt 100 ] ; then
  # prefix with "0"
  node=`printf "%02i" $node`
  port=90$node
  httpsPort=91$node
  stopkey=secret$node
  runlog=${runlog}-$node
fi

# look for jar file to start
jarfile=`ls -1S *jar 2>/dev/null|head -1`
if [ ''$jarfile == '' ]; then
  echo "Could not find jar file" 1>&2
  exit 1
fi

# export variables for java
JAVA_OPTS="$JAVA_OPTS -Djava.awt.headless=true"
JAVA_OPTS="$JAVA_OPTS -Djava.io.tmpdir=/tmp"
JAVA_OPTS="$JAVA_OPTS -Djava.net.preferIPv4Stack=true"
JAVA_OPTS="$JAVA_OPTS -Djetty.port=${port}"
JAVA_OPTS="$JAVA_OPTS -Dhttps.port=${httpsPort}"
JAVA_OPTS="$JAVA_OPTS -DSTOP.KEY=${stopkey}"
export JAVA_OPTS

start() {
    echo -n "Starting $jarfile on port $port "
    java $JAVA_OPTS -jar $jarfile >> $runlog 2>&1 &

    # wait for it to start, then install watchdog
    url=http://127.0.0.1:${port}/
    while true; do
      echo -n .
      curl -s $url > /dev/null && install && break
      sleep 2
    done
    echo
}

stop() {
    echo -n "Stopping $jarfile on port $port " 

    # first, uninstall watchdog
    uninstall

    # then stop jetty
    n=0
    while true; do
      pid=`ps auxww|grep $stopkey|grep -v grep|awk '{print $2}'`
      if [ $pid ]; then
        echo -n .
        if [ $n -lt 2 ]; then
          kill $pid
        fi
        if [ $n -gt 10 ]; then
          lsof -p $pid > logs/lsof-$pid 2>&1
          jstack -l $pid > logs/jstack-$pid 2>&1
          kill -9 $pid
        fi
        n=$(($n+1))
        sleep 1
      else
        break
      fi
    done
    echo
}

restart() {
  stop
  start
}

watch() {
  url=http://127.0.0.1:${port}/

  # look for reason to restart
  unset reason
  [ -f $runlog ] && tail -100 $runlog | grep OutOfMemoryError && reason=memory
  [ -n "$reason" ] || curl -s --connect-timeout 10 --max-time 10 $url > /dev/null || reason=http

  # restart if there is a reason for it
  if [ -n "$reason" ]
  then
    echo -n "restart node ${node} for reason ${reason} " ; date
    restart
  fi
}

install() {
  crontab -l 2>/dev/null | grep -v "watch $node" > crontab
  dir=$(cd $(dirname $0) ; pwd)
  echo "* * * * * cd $dir && bash control.sh watch $node >> logs/watchdog.log 2>&1 " >> crontab
  crontab crontab
  rm crontab
}

uninstall() {
  crontab -l | grep -v "watch $node" | crontab -
}

case "$1" in
  start)
    start
    ;;
  stop)
    stop
    ;;
  restart)
    restart
    ;;
  watch)
    watch
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|watch} [01-99]"
    ;;
esac
