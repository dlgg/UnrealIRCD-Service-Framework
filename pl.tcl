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
# Copyright (C) 2012 Damien Lesgourgues
# Author(s): Damien Lesgourgues
#
##############################################################################
puts [::msgcat::mc loadmodule "PartyLine"]

if {[info exists pl]} {
  if {$mysock(debug)==1} { puts [::msgcat::mc pl_alreadyload] }
} else {
  set pl 0
  set mysock(pl) ""
  set mysock(plauthed) ""
}

set mysock(plprotcmd) ".pass .close"

proc pl_server {} {
  global mysock
  if {[catch {socket -server pl -myaddr $mysock(plip) $mysock(plport)} error]} { puts "Erreur lors de l'ouverture du socket ([set error])"; return 0 }
  puts [::msgcat::mc pl_openport]
  set mysock(server) "1"
}

proc pl { sockpl addr dstport } {
  global mysock
  puts [::msgcat::mc pl_incconn]
  fileevent $sockpl readable [list pl_control $sockpl]
  lappend mysock(pl) $sockpl
  set mysock(pl) [nodouble $mysock(pl)]
  fconfigure $sockpl -buffering line
  fsend $mysock(sock) ":$mysock(nick) PRIVMSG $mysock(adminchan) :[::msgcat::mc pl_activated $sockpl $mysock(plport) $addr $dstport]"
}

proc closepl { socktoclose sockpl } {
  global mysock
  set mysock(pl) [lremove $mysock(pl) $socktoclose]
  set mysock(plauthed) [lremove $mysock(plauthed) $socktoclose]
  set msg [::msgcat::mc pl_close $socktoclose $sockpl]
  fsend $socktoclose $msg
  fsend $mysock(sock) ":$mysock(nick) PRIVMSG $mysock(adminchan) :\00304\002PL :\003\002 $msg"
  puts $msg
  close $socktoclose
}

proc pl_control { sockpl } {
  global mysock
  set argv [gets $sockpl arg]
  set isauth 0
  foreach pl $mysock(plauthed) { if {[test $pl $sockpl]} { set isauth 1 } }
  if {$argv=="-1"} {
    closepl $sockpl "system"
  }
  set arg [charfilter $arg]
  if {$mysock(debug)==1} {
    set protected 0
    foreach protcmd $mysock(plprotcmd) { if {[string tolower $protcmd]==[string tolower [lindex $arg 0]]} { set protected 1 } }
    if {$protected==0} {
      puts "<<< $sockpl <<< [join $arg]"
      foreach s $mysock(plauthed) { if {![string equal $s $sockpl]} { puts $s ">>> $sock >>> [join $arg]" } }
      puts $mysock(sock) ":$mysock(nick) PRIVMSG $mysock(adminchan) :\00312PL <<<\002 $sockpl \002<<<\003 [join $arg]"
    }
  }
  
  if {$isauth==1} {
    if {[lindex $arg 0]==".help"} {
      fsend $sockpl [::msgcat::mc pl_help0 $mysock(version)]
      fsend $sockpl " "
      fsend $sockpl [::msgcat::mc pl_help1]
      fsend $sockpl "------------------------------"
      fsend $sockpl " "
      fsend $sockpl ".close     [::msgcat::mc pl_help2]"
      fsend $sockpl ".who       [::msgcat::mc pl_help3]"
      fsend $sockpl ".rehash    [::msgcat::mc pl_help4]"
      fsend $sockpl ".die       [::msgcat::mc pl_help5]"
    }
    if {[lindex $arg 0]==".close"} {
      if {[lindex $arg 1]==""} {
        closepl $sockpl $sockpl
      } else {
        closepl [lindex $arg 1] $sockpl
      }
    }
    if {[lindex $arg 0]==".who"} {
      fsend $sockpl [::msgcat::mc pl_inpl $mysock(pl)]
      fsend $sockpl [::msgcat::mc pl_inplauth $mysock(plauthed)]
    }
    if {[lindex $arg 0]==".rehash"} {
      my_rehash
      fsend $mysock(sock) ":$mysock(nick) PRIVMSG $mysock(adminchan) :\00304\002PL :\003\002 [::msgcat::mc pl_rehash $sockpl]"
    }
    if {[lindex $arg 0]==".die"} {
      fsend $mysock(sock) ":$mysock(nick) PRIVMSG $mysock(adminchan) :\00304\002PL :\003\002 [::msgcat::mc pl_die $sockpl]"
      foreach bot $mysock(botlist) {
        fsend $mysock(sock) ":$bot QUIT :[::msgcat::mc cont_shutdown $sockpl]"
      }
      fsend $mysock(sock) ":$mysock(servername) SQUIT $mysock(hub) :[::msgcat::mc cont_shutdown $sockpl]"
      exit 0
    }
  } else {
    if {([lindex $arg 0]==".pass")} {
      if {([string equal [lindex $arg 1] $mysock(plpass)])} {
        lappend mysock(plauthed) $sockpl
        set mysock(plauthed) [nodouble $mysock(plauthed)]
        fsend $sockpl [::msgcat::mc pl_auth0]
        fsend $mysock(sock) ":$mysock(nick) PRIVMSG $mysock(adminchan) :[::msgcat::mc pl_auth1 $sockpl]"
        foreach s $mysock(plauthed) { if {![string equal $s $sockpl]} { puts $s ">>> $sock >>> [::msgcat::mc pl_auth1 $sockpl]" } }
      } else {
        fsend $sockpl [::msgcat::mc pl_notauth]
        fsend $mysock(sock) ":$mysock(nick) PRIVMSG $mysock(adminchan) :[::msgcat::mc pl_auth2 $sockpl]"
        foreach s $mysock(plauthed) { if {![string equal $s $sockpl]} { puts $s ">>> $sock >>> [::msgcat::mc pl_auth2 $sockpl]" } }
      }
    } elseif {[lindex $arg 0]==".close"} {
      if {[lindex $arg 1]==""} {
        closepl $sockpl $sockpl
      } else {
        closepl [lindex $arg 1] $sockpl
      } 
    } else {
      fsend $sockpl [::msgcat::mc pl_notauth]
    }
  }
}

puts [::msgcat::mc pl_loaded]
if {$pl=="0"} { puts [::msgcat::mc pl_activation $mysock(plip) $mysock(plport)]; pl_server; set pl 1 }

