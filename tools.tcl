#!/usr/bin/env tclsh
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
# Copyright (C) 2013 Damien Lesgourgues
# Author(s): Damien Lesgourgues
#
##############################################################################
puts [::msgcat::mc loadmodule "Tools"]

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

  # if/then/else compacted
  # Usage : [proc who return boolean value] { then cmd to execute } { else cmd to execute }
  # Ex: [expr $x<100] {puts Yes} {puts No}
  proc 0 {then else} {uplevel 1 $else}
  proc 1 {then else} {uplevel 1 $then}

  # One missing command for managing lists. Remove an element from the list without replacing it with an empty string
  proc lremove { list element } { return [lsearch -all -inline -not -exact $list $element] }
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
    if {[llength $var]==1} { return $var }
    set final ""
    set var [join $var]
    foreach i $var {
      set l 1
      foreach j $final { if {[testcs $j $i]} { set l 0 } }
      if {[test $l 1]} { lappend final $i }
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
    if {$days != 0} {append res " $days [::msgcat::mc days]"}
    if {$hours != 0} {append res " $hours [::msgcat::mc hours]"}
    if {$minutes != 0} {append res " $minutes [::msgcat::mc minutes]"}
    if {$seconds != 0} {append res " $seconds [::msgcat::mc seconds]"}
    return $res
  }
  proc rand { multiplier } {
    return [expr { int( rand() * $multiplier ) }]
  }

  proc random { min max } {
    set maxFactor [expr [expr $max + 1] - $min]
    set value [expr int([expr rand() * 100])]
    set value [expr [expr $value % $maxFactor] + $min]
    return $value
  }

  # Conversion of unreal server numeric from unreal specific base 64 to decimal
  set ub64chars { 0 1 2 3 4 5 6 7 8 9 A B C D E F G H I J K L M N O P Q R S T U V W X Y Z a b c d e f g h i j k l m n o p q r s t u v w x y z \{ \} }
  set ub64charsnickip { A B C D E F G H I J K L M N O P Q R S T U V W X Y Z a b c d e f g h i j k l m n o p q r s t u v w x y z 0 1 2 3 4 5 6 7 8 9 + / }
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
    set base [llength $baselist]
    foreach char [split $num ""] {
      set d [lsearch $baselist $char]
      if {$d == -1} {error "invalid base-$base digit '$char' in $num"}
      set sum [expr {$sum * $base + $d}]
    }
    return $sum
  }

  # Using an array as persistent database
  # ::tools::writeDB $array $file
  proc writeDB { var file } {
    set fp [open $file w]
    puts $fp [list array set db [array get db]]
    close $fp
    return
  }
  # unset $array; set array [readDB $file]
  proc readDB { file } { source $file } 
  
  proc pluralize { number } { if { $number > 1} { return "s" } }
  
  proc getpreprocname { } {
  	return "[lindex [split [info level [expr [info level] - 2]]] 0] >>> [lindex [split [info level [expr [info level] - 1]]] 0]"
  }

  # Manage timers
  if {![info exists  ::tools::timers(list)]} { array set  ::tools::timers { list "" } }
  if {![info exists ::tools::utimers(list)]} { array set ::tools::utimers { list "" } }
  
  proc timer { time call } {
    #timer <minutes> <proc_a_lancer>
    set stime [expr {$time * 1000 * 60}]
    set id [after $stime $call]
    lappend ::tools::timers(list) $id
    set ::tools::timers(start-$id) [clock seconds]
    set ::tools::timers(time-$id) [expr {$time * 60}]
    set ::tools::timers(call-$id) $call
    puts "Start timer $id : $call from [::tools::getpreprocname]"
    return $id
  }
  proc utimer { time call } {
    #utimer <secondes> <proc_a_lancer>
    set stime [expr {$time * 1000 }]
    set id [after $stime $call]
    lappend ::tools::utimers(list) $id
    set ::tools::utimers(start-$id) [clock seconds]
    set ::tools::utimers(time-$id) [expr {$time * 60}]
    set ::tools::utimers(call-$id) $call
    puts "Start utimer $id : $call from [::tools::getpreprocname]"
    return $id
  }
  
  proc killtimer { ID } {
    foreach t [array names utimers] { if {[string equal $utimers($t) $ID]} { set utimers($t) [::tools::lremove $utimers($t) $ID]} }
    return
  }
  proc killutimer { ID } {
    foreach t [array names utimers] { if {[string equal $utimers($t) $ID]} { set utimers($t) [::tools::lremove $utimers($t) $ID]} }
    return
  }
  
  proc timers {} { return }
  proc utimers {} { return }
  
  proc timerexists {command} { return }
  proc utimerexists {command} { return }
  
  proc every {seconds body} {
    eval $body
    after [expr {$seconds * 1000}] [list ::tools::every $seconds $body]
    return
  }
  proc everym {m body} {
    eval $body; timer $m [list everym $m $body]
    return
  }
  proc everys {s body} {
    eval $body; timer $s [list everys $s $body]
    return
  }

  proc tok { cmd } {
    if {$::irc::token} {
      switch -- $cmd {
        EOS        { set out "ES" }
        NETINFO    { set out "AO" }
        NICK       { set out "&" }
        MODE       { set out "G" }
        UMODE2     { set out "|" }
        QUIT       { set out "," }
        KILL       { set out "." }
        SETHOST    { set out "AA" }
        CHGHOST    { set out "AL" }
        SETIDENT   { set out "AD" }
        CHGIDENT   { set out "AZ" }
        SETNAME    { set out "AE" }
        CHGNAME    { set out "BK" }
        WHOIS      { set out "#" }
        SQUIT      { set out "-" }
        SDESC      { set out "AG" }
        PING       { set out "8" }
        PONG       { set out "9" }
        STATS      { set out "2" }
        SJOIN      { set out "~" }
        JOIN       { set out "C" }
        PART       { set out "D" }
        KICK       { set out "H" }
        MODE       { set out "G" }
        INVITE     { set out "*" }
        SAJOIN     { set out "AX" }
        SAPART     { set out "AY" }
        SAMODE     { set out "o" }
        TOPIC      { set out ")" }
        SVSKILL    { set out "h" }
        SVSMODE    { set out "n" }
        SVS2MODE   { set out "v" }
        SVSSNO     { set out "BV" }
        SVS2SNO    { set out "BW" }
        SVSNICK    { set out "e" }
        SVSJOIN    { set out "BX" }
        SVSPART    { set out "BT" }
        SVSO       { set out "BB" }
        SVSNOOP    { set out "f" }
        SVSNLINE   { set out "BR" }
        SVSFLINE   { set out "BC" }
        PRIVMSG    { set out "!" }
        NOTICE     { set out "B" }
        SENDUMODE  { set out "AP" }
        SMO        { set out "AU" }
        SENDSNO    { set out "Ss" }
        CHATOPS    { set out "p" }
        WALLOPS    { set out "=" }
        GLOBOPS    { set out "]" }
        ADMINCHAT  -
        ADCHAT     { set out "x" }
        NACHAT     { set out "AC" }
        TKL        { set out "BD" }
        SQLINE     { set out "c" }
        UNSQLINE   { set out "d" }
        VERSION    { set out "+" }
        INFO       { set out "/" }
        LINKS      { set out "0" }
        HELP       { set out "4" }
        ERROR      { set out "5" }
        AWAY       { set out "6" }
        CONNECT    { set out "7" }
        PASS       { set out "<" }
        TIME       { set out ">" }
        ADMIN      { set out "&" }
        LAG        { set out "AF" }
        KNOCK      { set out "AI" }
        CREDITS    { set out "AJ" }
        LICENSE    { set out "AK" }
        RPING      { set out "AM" }
        RPONG      { set out "AN" }
        ADDMOTD    { set out "AQ" }
        ADDOMOTD   { set out "AR" }
        SVSMOTD    { set out "AS" }
        OPERMOTD   { set out "AV" }
        TSCTL      { set out "AW" }
        SWHOIS     { set out "BA" }
        VHOST      { set out "BE" }
        BOTMOTD    { set out "BF" }
        HTM        { set out "BH" }
        DCCDENY    { set out "BI" }
        UNDCCDENY  { set out "BJ" }
        SHUN       { set out "BL" }
        CYCLE      { set out "BP" }
        MODULE     { set out "BQ" }
        SVSLUSERS  { set out "BU" }
        SVSSILENCE { set out "Bs" }
        SVSWATCH   { set out "Bw" }
        LUSERS     { set out "E" }
        MOTD       { set out "F" }
        REHASH     { set out "O" }
        RESTART    { set out "P" }
        CLOSE      { set out "Q" }
        DNS        { set out "T" }
        TEMPSHUN   { set out "Tz" }
        SILENCE    { set out "U" }
        AKILL      { set out "V" }
        UNKLINE    { set out "X" }
        RAKILL     { set out "Y" }
        LOCOPS     { set out "^" }
        PROTOCTL   { set out "_" }
        WATCH      { set out "`" }
        TRACE      { set out "b" }
        UNZLINE    { set out "r" }
        RULES      { set out "t" }
        MAP        { set out "u" }
        DALINFO    { set out "w" }
        default    { set out $cmd}
      }
    } else { set out [string toupper $cmd] }
    return $out
  }

  # IP Management
  proc intip { ip } {
    binary scan [::tools::normalize4 $ip] I out
    return $out
  }
  proc normalize4 {ip} {
    set octets [split $ip .]
    if {[llength $octets] > 4} {
      return -code error "invalid ip address \"$ip\""
    } elseif {[llength $octets] < 4} {
      set octets [lrange [concat $octets 0 0 0] 0 3]
    }
    foreach oct $octets { if {$oct < 0 || $oct > 255} { return -code error "invalid ip address" } }
    return [binary format c4 $octets]
  }

  package provide extend 1.0
  package require Tcl 8.5

  proc extend {cmd body} {
    if {![namespace exists ${cmd}]} {
        set wrapper [string map [list %C $cmd %B $body] {
            namespace eval %C {}
            rename %C %C::%C
            namespace eval %C {
                proc _unknown {junk subc args} {
                    return [list %C::%C $subc]
                }
                namespace ensemble create -unknown %C::_unknown
            }
        }]
    }

    append wrapper [string map [list %C $cmd %B $body] {
        namespace eval %C {
            %B
            namespace export -clear *
        }
    }]
    uplevel 1 $wrapper
  }
}

# Link to IRC Network
proc ::irc::socket_connect {} {
  if {$::irc::ssl} {
    package require tls
    ::tls::init -require false -ssl3 true
    if {$::debug==1} { puts [::msgcat::mc initssllink1 $::irc::ip $::irc::port] }
    if {[catch {set ::irc::sock [::tls::socket $::irc::ip $::irc::port]} error]} { puts [::msgcat::mc sockerror $error]); after $::irc::reconnect; ::irc::socket_connect; return 0 }
    if {![::tls::handshake $::irc::sock]} { puts "Error during TLS Handshake. Shutdown of service."; exit 1 }
  } else {
    if {$::debug==1} { puts [::msgcat::mc initlink1 $::irc::ip $::irc::port] }
    if {[catch {set ::irc::sock [socket $::irc::ip $::irc::port]} error]} { puts [::msgcat::mc sockerror $error]); after $::irc::reconnect; ::irc::socket_connect; return 0 }
  }
  fileevent $::irc::sock readable ::irc::socket_control
  fconfigure $::irc::sock -buffering line
  ::irc::netsync
  vwait ::irc::wait
  return
}

proc ::irc::netsync {} {
  ::irc::send "PASS $::irc::password"
  set protoctl [list "PROTOCTL" "NOQUIT" "NICKv2" "UMODE2" "VL" "NS" "TKLEXT" "CLK" "SJOIN" "SJOIN2" "SJ3" "ESVID" ]
  if {$::irc::token} {
    lappend protoctl "TOKEN"
  }
  ::irc::send [join $protoctl " "]
  ::irc::send "SERVER $::irc::servername 1 :U$::irc::uversion-Fh6XiOoEe-$::irc::numeric UnrealIRCD Service Framework V.$::irc::version"
  ::irc::bot_init $::irc::nick $::irc::username $::irc::hostname $::irc::realname
  if ([info exists ::irc::hook(sync)]) { foreach hooks $::irc::hook(sync) { if {$::debug==1} { puts "Hook sync call : $hooks" }; $hooks } }
  ::irc::send "NETINFO 0 [::tools::unixtime] $::irc::uversion * 0 0 0 :$::irc::netname"
  ::irc::send "EOS"
  return 0
}

# Timeout management
proc ::irc::timeout {} {
  if {$::debug==1} { puts "Timeout detected. Closing all sockets and cancelling all timers." }
  catch {close $::irc::sock}
  foreach t [after info] { after cancel $t }
  if {$::debug==1} { puts "Timeout detected. Relink service." }
  set ::irc::connectout [after 60000  ::irc::timeout]
  ::irc::socket_connect
  return
}
proc ::irc::reset_timeout {} {
  if {[info exists ::irc::timeout]} {
    if {$::debug==1} { puts "Stoping timeout timer : $::irc::timeout from [::tools::getpreprocname]" }
    catch { after cancel $::irc::timeout }
    unset ::irc::timeout
  }
  if {$::debug==1} { puts "Starting timeout timer for 3 minutes from [::tools::getpreprocname]" }
  set ::irc::timeout [after 180000 ::irc::timeout]
  return
}
proc ::irc::pinghub {} { ::irc::send "[tok PING] $::irc::servername" }

# Proc to register a hook
proc ::irc::hook_register { hook callpoint } {
  if {$::debug==1} { puts "Registering hook : $hook => $callpoint" }
  set valid 0
  foreach el $::irc::hooklist {
    if {[string match -nocase $el $hook]} { set valid 1 }
  }
  if {[string match -nocase command-* $hook]} {
    set cmd [lindex [split $hook -] 1]
    puts "Check registering hook command : $cmd"
    foreach prot "raw rehash source ssl tok dcc die" { if {[::tools::test $prot $cmd]} { puts "Trying to register a protected command : $cmd"; return } }
  }
  if {$valid==1} {
    lappend ::irc::hook($hook) $callpoint
    set ::irc::hook($hook) [::tools::nodouble $::irc::hook($hook)]
  } else {
    puts "Trying to register a non existing hook : $hook"
  }
  return
}

# Proc gestion du service
proc ::irc::rehash {} {
  if {$::pl==1} {
    puts [::msgcat::mc closepls]
    foreach pl $::pl::socks { ::pl::closepl $pl "rehash" }
  }
  source config.tcl
  source tools.tcl
  source controller.tcl
  source pl.tcl
  if {$debug==1} { puts "List of modules to load : $::irc::modules" }
  foreach file $::irc::modules {
    append file ".tcl"
    set file modules/$file
    if {$debug==1} { puts "Checking if exist : $file" }
    if {[file exists $file]} {
      if {$debug==1} { puts "Trying to load : $file" }
      if {[catch {source $file} err]} { puts "Error loading $file \n$err"; exit }
    } else {
      if {$debug==1} { puts "File not exists : $file" }
      puts [::msgcat::mc filenotexist $file]
    }
  }
  ::irc::reset_timeout
  ::irc::send ":$::irc::nick [tok PRIVMSG] $::irc::adminchan :\00304[::msgcat::mc rehashdone]"
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
proc ::pl::send {sock data} {
  # TODO check if given sock is a pl
  if {$::debug==1} {
    set datanc [::tools::stripmirc $data]
    puts ">>> \002$sock\002 >>> $datanc"
  }
  puts $sock $data
  return
}

proc ::irc::bot_init { nick user host gecos } {
  ::irc::send "[tok TKL] + Q * $nick $::irc::servername 0 [::tools::unixtime] :Reserved for $::irc::svcname"
  ::irc::send "[tok NICK] $nick 0 [::tools::unixtime] $user $host [::tools::dec2base $::irc::numeric $::tools::ub64chars] 0 +oSqB * * :$gecos"
  if {$nick==$::irc::nick} {
    join_chan $::irc::nick $::irc::adminchan
    foreach chan $::irc::chanlist { join_chan $::irc::nick $chan }
  }
  lappend ::irc::botlist $nick
  set ::irc::botlist [::tools::nodouble $::irc::botlist]
  lappend ::irc::userlist $nick
  set ::irc::userlist [::tools::nodouble $::irc::userlist]
  lappend ::irc::users($::irc::servername) $nick
  set ::irc::users($::irc::servername) [::tools::nodouble $::irc::users($::irc::servername)]
  if {$::debug==1} { puts "My bots are : $::irc::botlist" }
  return
}

proc ::irc::join_chan {bot chan} {
  if {$chan=="0"} {
    ::irc::send ":$::irc::nick [tok PRIVMSG] $::irc::adminchan :[::msgcat::mc botjoin0 $bot]"
  } else {
    ::irc::send ":$bot [tok JOIN] $chan"
    if {$bot==$::irc::nick} {
      ::irc::send ":$bot [tok MODE] $chan +qo $bot $bot"
    } else {
      ::irc::send ":$::irc::nick [tok MODE] $chan +ao $bot $bot"
    }
    lappend ::irc::users([string tolower $chan]) $bot
    set ::irc::users([string tolower $chan]) [::tools::nodouble $::irc::users([string tolower $chan])]
  }
  return
}

proc ::irc::part_chan {bot chan} {
  if {$chan=="0"} {
    ::irc::send ":$::irc::nick [tok PRIVMSG] $::irc::adminchan :[::msgcat::mc botpart0 $bot]"
  } else {
    ::irc::send ":$bot [tok PART] $chan :[::msgcat::mc botpart1]"
    set ::irc::users($chan) [::tools::lremove $::irc::users($chan) $bot]
    if {$::debug==1} { puts "There is [llength $::irc::users($chan)] users on $chan : $::irc::users($chan)" }
    if {[llength $::irc::users($chan)]==0} {
      if {$::debug==1} { puts "Removing $chan from ::irc::chanlist" }
      set ::irc::chanlist [::tools::lremove $::irc::chanlist $chan]
      unset ::irc::users($chan)
    }
  }
  return
}

proc ::irc::is_admin { nick } {
  if {![info exists ::irc::regusers]} { return 0 }
  if { [llength $::irc::regusers] < 1 } { return 0 }
  puts [lsearch -nocase -exact $::irc::root $nick]
  if {[lsearch -nocase -exact $::irc::root $nick] != "-1"} { if {[lsearch -exact $::irc::regusers $nick] >= 0} { return 1 } }
  return 0
}

proc ::irc::is_chan { chan } { [string equal [string index $chan 0] "#"] { return 1 } { return 0 } }

proc ::irc::parse_umodes { nick modes } {
  set mode "add"
  if {$::debug==1} { puts "CHG UMODES : allmodes : $modes" }
  for {set i 0} {$i<[string length $modes]} {incr i} {
    switch [string index $modes $i] {
      + { set mode "add" }
      - { set mode "del" }
      A { if {$::debug==1} { puts "CHG UMODE : $nick $mode is a Server Admin" } }
      a { if {$::debug==1} { puts "CHG UMODE : $nick $mode is a Services Admin" } }
      B { if {$::debug==1} { puts "CHG UMODE : $nick $mode is a bot" } }
      C { if {$::debug==1} { puts "CHG UMODE : $nick $mode is a Co-Admin" } }
      d { if {$::debug==1} { puts "CHG UMODE : $nick $mode cannot receive msg channels or timestamp/svid to services" } }
      G { if {$::debug==1} { puts "CHG UMODE : $nick $mode badword filtering" } }
      g { if {$::debug==1} { puts "CHG UMODE : $nick $mode can send and read to globops and locops" } }
      H { if {$::debug==1} { puts "CHG UMODE : $nick $mode hide is oper status" } }
      h { if {$::debug==1} { puts "CHG UMODE : $nick $mode is available for help" } }
      i { if {$::debug==1} { puts "CHG UMODE : $nick $mode is invisible" } }
      I { if {$::debug==1} { puts "CHG UMODE : $nick $mode hide is idle" } }
      N { if {$::debug==1} { puts "CHG UMODE : $nick $mode is a Network Admin" } }
      O { if {$::debug==1} { puts "CHG UMODE : $nick $mode is a locop" } }
      o { if {$::debug==1} { puts "CHG UMODE : $nick $mode is a globop" } }
      p { if {$::debug==1} { puts "CHG UMODE : $nick $mode hide his channels" } }
      q { if {$::debug==1} { puts "CHG UMODE : $nick $mode cannot be kick" } }
      R { if {$::debug==1} { puts "CHG UMODE : $nick $mode cannot receive priv msg/notice" } }
      r { if {$::debug==1} { puts "CHG UMODE : $nick $mode is reg. Call to ::irc::reg_user $mode $nick" } ; ::irc::reg_user $mode $nick }
      S { if {$::debug==1} { puts "CHG UMODE : $nick $mode is protect by services" } }
      s { if {$::debug==1} { puts "CHG UMODE : $nick $mode can read server notices" } }
      T { if {$::debug==1} { puts "CHG UMODE : $nick $mode cannot receive CTCP" } }
      t { if {$::debug==1} { puts "CHG UMODE : $nick $mode use a /vhost" } }
      V { if {$::debug==1} { puts "CHG UMODE : $nick $mode is a WebTV user" } }
      v { if {$::debug==1} { puts "CHG UMODE : $nick $mode can receive DCC infect notice" } }
      W { if {$::debug==1} { puts "CHG UMODE : $nick $mode view when a user whois him" } }
      w { if {$::debug==1} { puts "CHG UMODE : $nick $mode can read wallops" } }
      x { if {$::debug==1} { puts "CHG UMODE : $nick $mode has an hidden hostname" } }
      z { if {$::debug==1} { puts "CHG UMODE : $nick $mode use SSL" } }
    }
  }
  return
}
proc ::irc::reg_user { mode nick } {
  switch $mode {
    add { puts "adding $nick to regusers"; lappend ::irc::regusers $nick; set ::irc::regusers [::tools::nodouble $::irc::regusers] }
    del {
      if {([info exists ::irc::regusers]) && ([llength ::irc::regusers] > 0)} {
        puts "removing $nick from regusers"
        set ::irc::regusers [::tools::lremove $::irc::regusers $nick]
      }
    }
    default { puts "Problem to reg an user. Call is ::irc::reg_user $mode $nick" }
  }
  if {($::debug) && ([info exists ::irc::regusers])} { puts "List of registered users : $::irc::regusers" }
  return
}

proc ::irc::user_join { nick chan modes } {
  set chan [string tolower $chan]
  lappend ::irc::users($chan) $nick
  set ::irc::users($chan) [::tools::nodouble $::irc::users($chan)]
  lappend ::irc::chanlist $chan
  set ::irc::chanlist [::tools::nodouble $::irc::chanlist]
  lappend ::irc::modeslist($chan) ($nick, $modes)
  # Hooks for global join
  if {[info exists ::irc::hook(join)]} { foreach hookj $::irc::hook(join) { $hookj $nick $chan } }
  # Hooks for specific join on a chan
  if {[info exists ::irc::hook(join-[string tolower $chan])]} { foreach hookj $::irc::hook(join-[string tolower $chan]) { $::irc::hook(join-[string tolower $chan]) $nick } }
  return
}

proc ::irc::user_part { nick chan } {
  set chan [string tolower $chan]
  set ::irc::users($chan) [::tools::lremove $::irc::users($chan) $nick]
  if {$::debug==1} { puts "There is [llength $::irc::users($chan)] users on $chan : $::irc::users($chan)" }
  if {[llength $::irc::users($chan)]==0} { if {$::debug==1} { puts "Removing $chan from ::irc::chanlist" }; set ::irc::chanlist [::tools::lremove $::irc::chanlist $chan]; unset ::irc::users($chan) }
  return
}

proc ::irc::user_quit { nick } {
  ::irc::reg_user del $nick
  set ::irc::userlist [::tools::lremove $::irc::userlist $nick]
  foreach arr [array names ::irc::users *] {
    set ::irc::users($arr) [::tools::lremove $::irc::users($arr) $nick]
    if {[llength $::irc::users($arr)]==0} {
      if {[::irc::is_chan $arr]} {
        if {$::debug==1} { puts "Removing $arr from ::irc::chanlist" }
        set ::irc::chanlist [::tools::lremove $::irc::chanlist $arr]
      }
      if {$::debug} { puts "Removing ::irc::users($arr) array key." }
      unset ::irc::users($arr)
    }
  }
  return
}

proc ::irc::shutdown { nick reason } {
  if {[info exists ::pl]} { if {$::pl==1} {
    foreach s $::pl::socks { ::pl::closepl $s $nick }
  } }
  if {$reason != ""} { set quitmsg "[::msgcat::mc cont_shutdown $nick] (Raison : $reason)" } else { set quitmsg "[::msgcat::mc cont_shutdown $nick]" }
  ::irc::send ":$::irc::nick [tok QUIT] :$quitmsg"
  foreach bot $::irc::botlist { ::irc::send ":$bot [tok QUIT] :$quitmsg" }
  ::irc::send ":$::irc::servername [tok SQUIT] $::irc::hub :$quitmsg"
  close $::irc::sock
  exit 0
}

# Import of useful tools
namespace eval ::irc { namespace import ::tools::tok }
namespace eval ::pl  { namespace import ::tools::tok }
namespace import ::tools::0 ::tools::1

# vim: set fenc=utf-8 sw=2 sts=2 ts=2 et filetype=tcl
