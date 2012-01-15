#!/bin/bash

# Definitions of variables
logfile="framework.log"
pidfile=$(grep 'mysock(pid)' config.tcl|awk '{print $3}')
tclsh=$(which tclsh)
svcname="Framework"

# Recuperation of the pid value if the pidfile exist
if [ -e ${pidfile} ]; then
  pid=$(cat $pidfile)
else
  pid=none
fi

# Check if TCL GameService is running. 0 for yes / 1 for no.
testprocess() {
  if [ z${pid} == "znone" ]; then return 1; fi
  ps x | grep -v grep | grep ${pid} >/dev/null 2>&1
  return $?
}

startprocess() {
  if [ ! -x ${tclsh} ]; then
    echo "ERROR : tclsh is not found. Exiting." >&2
    exit 1
  fi
  if testprocess; then
    echo "${svcname} is already running." >&2
  else
    nohup ${tclsh} ./main.tcl >>${logfile} 2>&1 &
  fi
}

stopprocess() {
  if [ z${pid} == "znone" ]; then
    echo "${framework} is not started or has been started by an bad way." >&2
  else
    kill -$1 ${pid}
    sleep 2
    echo "Check if ${framework} is stoped"
    if testprocess; then
      echo "${framework} seem to be always running. Consider to use $0 forcestop." >&2
    else
      rm $pidfile
    fi
  fi
}

case "$1" in
  start)
    echo "Starting ${framework}"
    startprocess
    ;;

  stop)
    echo "Stopping ${framework}"
    stopprocess 15
    ;;

  forcestop)
    echo "Force stopping of ${framework}"
    stopprocess 9
    ;;

  restart)
    stopprocess && sleep 2 && startprocess
    ;;

  *)
    echo "Usage $0 {start|stop|restart|forcestop}"
    ;;

esac

