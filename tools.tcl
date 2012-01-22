#!/usr/bin/tclsh
##############################################################################
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the Licence, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
# Product name : UnrealIRCD Service Framework
# Copyright (C) 2011 Damien Lesgourgues
# Author(s): Damien Lesgourgues
#
##############################################################################
puts [::msgcat::mc loadmodule "Tools"]

# if/then/else compacted
# Usage : [proc who return boolean value] { then cmd to execute } { else cmd to execute }
# Ex: [expr $x<100] {puts Yes} {puts No}
proc 0 {then else} {uplevel 1 $else}
proc 1 {then else} {uplevel 1 $then}

namespace eval tools {
  namespace export *

  # Clean string to be safe for interpreter
  proc charfilter { arg } { return [string map {"\\" "\\\\" "\{" "\\\{" "\}" "\\\}" "\[" "\\\[" "\]" "\\\]" "\'" "\\\'" "\"" "\\\""} $arg] }
  # Clean irc color codes : bold \002, color \003FF,BB, remove all codes \017, underline \026, reverse \037
  proc stripmirc { arg } { return [regsub -all -- {\002|\037|\026|\017|\003(\d{1,2})?(,\d{1,2})?} $arg ""] }

  # Two little "alias" for comparing 2 strings
  proc test { a b } { return [string equal -nocase $a $b] }
  proc testcs { a b } { return [string equal $a $b] }

  # Return the current datetime in epoch format
  proc unixtime {} { return [clock seconds] }

  # Write the pid of the current process in a file fro crons systems
  proc write_pid { pidfile } {
    set f [open $pidfile "WRONLY CREAT TRUNC" 0600]
    puts $f [pid]
    close $f
    return
  }

  # One missing command for managing lists. Remove an element from the list without replacing it with an empty string
  proc lremove { list pattern } { return [lsearch -all -inline -not -exact $list $pattern] }
  proc lremove-old { list element } {
    set final ""
    foreach l $list { if {![string equal -nocase $l $element]} { lappend final $l } }
    return $final
  }
  proc llreplace { list old new } {
    set final ""
    foreach l $list { if {[string equal -nocase $l $old]} { lappend final $new } else { lappend final $l } }
    return $final
  }
  
  proc nodouble { var } {
    set final ""
    foreach i $var {
      if {[llength $final] == 1} {
        return $i
      } else {
        set l 1
        foreach j $final { if {[testcs $j $i]} { set l 0 } }
        if {[test $l 1]} { lappend final $i }
      }
    }
    return $final
  }

  # Eggdrop tcl command
  proc duration {s} {
    set days [expr {$s / 86400}]
    set hours [expr {$s / 3600}]
    set minutes [expr {($s / 60) % 60}]
    set seconds [expr {$s % 60}]
    set res ""
    if {$days != 0} {append res "$days [::msgcat::mc days]"}
    if {$hours != 0} {append res "$hours [::msgcat::mc hours]"}
    if {$minutes != 0} {append res " $minutes [::msgcat::mc minutes]"}
    if {$seconds != 0} {append res " $seconds [::msgcat::mc seconds]"}
    return $res
  }
  proc rand { multiplier } {
    return [expr { int( rand() * $multiplier ) }]
  }

  # Conversion of unreal server numeric from unreal specific base 64 to decimal
  set ub64chars { 0 1 2 3 4 5 6 7 8 9 A B C D E F G H I J K L M N O P Q R S T U V W X Y Z a b c d e f g h i j k l m n o p q r s t u v w x y z \{ \} }
  proc dec2base { num baselist } {
    set res {}
    set base [llength $baselist]
    while {$num/$base != 0} {
      set rest [expr { $num % $base } ]
      set res [lindex $baselist $rest]$res
      set num [expr { $num / $base } ]
    }
    set res [lindex $baselist $num]$res
    return $res
  }
  proc base2dec { num baselist } {
    set sum 0
    foreach char [split $num ""] {
      set d [lsearch $baselist $char]
      if {$d == -1} {error "invalid unrealbase-64 digit '$char' in $num"}
      set sum [expr {$sum * 64 + $d}]
    }
    return $sum
  }

  # Using an array as persistent database
  # ::tools::writeDB $array $file
  proc writeDB { var file } {
    set fp [open Library.db w]
    puts $fp [list array set db [array get db]]
    close $fp
  }
  # unset $array; set array [readDB $file]
  proc readDB { file } { source $file } 
}


# Link to IRC Network
proc ::irc::socket_connect {} {
  if {$::debug)==1} { puts [::msgcat::mc initlink1 $::irc::ip $::irc::port] }
  if {[catch {set ::irc::sock [socket $::irc::ip $::irc::port]} error]} { puts [::msgcat::mc sockerror $error]); close $::irc::sock; ::irc::socket_connect; return 0 }
  fileevent $::irc::sock readable ::irc::socket_control
  fconfigure $::irc::sock -buffering line
  vwait ::irc::wait
  return
}

# Proc gestion du service
proc ::irc::rehash {} {
  #puts [::msgcat::mc closepls]
  #foreach pl $mysock(pl) { closepl $pl "rehash" }
  source config.tcl
  source tools.tcl
  source controller.tcl
  #source pl.tcl
  foreach file ::irc::toload {
    append file ".tcl"
    set file modules/$file
    if {[file exists $file]} {
      if {[catch {source $file} err]} { puts "Error loading $file \n$err" }
    } else {
      puts [::msgcat::mc filenotexist $file]
    }
  }
  ::irc::send ":$::irc::nick PRIVMSG $::irc::adminchan :\00304[::msgcat::mc rehashdone]"
  return
}

proc ::irc::send {data} {
  if {$::debug==1} {
    set datanc [::tools::stripmirc $data]
    puts ">>> \002$::irc::sock\002 >>> $datanc"
  }
  puts $::irc::sock $data
  return
}
proc ::pl::send {data} {
  if {$::debug==1} {
    set datanc [::tools::stripmirc $data]
    puts ">>> \002$::pl::sock\002 >>> $datanc"
  }
  puts $::pl::sock $data
  return
}

proc ::irc::bot_init { nick user host gecos } {
  ::irc::send "TKL + Q * $nick $::irc::servername 0 [::tools::unixtime] :Reserved for ::irc::svcname"
  ::irc::send "NICK $nick 0 [::tools::unixtime] $user $host $::irc::servername 0 +oSqB * * :$gecos"
  if {$nick==$::irc::nick} {
    join_chan $::irc::nick $::irc::adminchan
    foreach chan $::irc::chanlist {
      join_chan $::irc::nick $chan
    }
  }
  lappend ::irc::botlist $nick
  set ::irc::botlist [::tools::nodouble $::irc::botlist]
  lappend ::irc::userlist $nick
  set ::irc::userlist [::tools::nodouble $::irc::userlist]
  lappend ::irc::users($::irc::servername) $nick
  set ::irc::users($::irc::servername) [::tools::nodouble $::irc::users($::irc::servername)
  if {$::debug==1} { puts "My bots are : $::irc::botlist" }
  return
}

proc ::irc::join_chan {bot chan} {
  if {$chan=="0"} {
    ::irc::send ":$::irc::nick PRIVMSG $::irc::adminchan :[::msgcat::mc botjoin0 $bot]"
  } else {
    if {$bot==$::irc::nick} {
      ::irc::send ":$bot JOIN $chan"
      ::irc::send ":$bot MODE $chan +qo $bot $bot"
    } else {
      ::irc::send ":$bot JOIN $chan"
      ::irc::send ":$::irc::nick MODE $chan +ao $bot $bot"
    }
    lappend ::irc::mychans [join $chan]
    set ::irc::mychans [::tools::nodouble $mysock(mychans)]
    lappend ::irc::users([string tolower $chan]) $bot
    set ::irc::users([string tolower $chan]) [::tools::nodouble $::irc::users([string tolower $chan])]
    if {$::debug==1} { puts "My chans are : $::irc::mychans" }
  }
  return
}

proc ::irc::is_admin { nick } { [string equal -nocase $nick $::irc::root] { return 1 } { return 0 } }
proc ::irc::ischan { chan } { [string equal [string index $chan 0] "#"] { return 1 } { return 0 } }
