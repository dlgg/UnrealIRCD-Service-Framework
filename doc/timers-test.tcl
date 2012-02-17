#!/usr/bin/env tclsh

# timers management
if {![info exists  timers(list)]} { array set  timers { list "" } }
if {![info exists utimers(list)]} { array set utimers { list "" } }

# start a timer/utimer
proc timer { time call } {
  #timer <minutes> <proc_a_lancer>
  set name $call; append name [clock seconds]
  set stime [expr {$time * 1000 * 60}]
  set id [after $stime $call]
  set timers($name) $id
  set timers($id) $name
  set timers(list) $id
  return $id
}
proc utimer { time call } {
  #utimer <secondes> <proc_a_lancer>
  set name $call; append name [clock seconds]
  set stime [expr {$time * 1000 }]
  set id [after $stime $call]
  set utimers($name) $id
  set utimers($id) $name
  set utimers(list) $id
  return $id
}

# Kill timer/utimer based on his ID
proc killtimer { ID } {
  after cancel $ID
  foreach t [array names timers] { if {[string equal $timers($t) $ID]} { array unset timers $t } }
  return
}
proc killutimer { ID } {
  after cancel $ID
  foreach t [array names utimers] { if {[string equal $utimers($t) $ID]} { array unset utimers $t } }
  return
}

proc timers {} {
  # Liste les timer
  return [array names timers]
}
proc utimers {} {
  # Liste les utimer
  return [array names utimers]
}

proc timerexists {command} {
  foreach i [timers] { if {![string compare $command [lindex $i 1]]} then   return [lindex $i 2] } }
  return
}
proc utimerexists {command} {
  foreach i [utimers] { if {![string compare $command [lindex $i 1]]} then   return [lindex $i 2] } }
  return
}

