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
puts [::msgcat::mc loadmodule "Master Bot Controller"]

[info exists service] { } { set service 0 }

proc ::irc::socket_control {} {
  set argv [gets $::irc::sock rawarg]
  if {$argv=="-1"} {
    puts [::msgcat::mc cont_sockclose]
    close $::irc::sock
    exit 0
  }
  set arg [::tools::charfilter $rawarg]
  if {$::debug==1} { puts "<<< $::irc::sock <<< [::tools::stripmirc $arg]" }

  if {[lrange $arg 1 end]=="NOTICE AUTH :*** Looking up your hostname..."} {
    ::irc::send "PROTOCTL NOQUIT NICKv2 UMODE2 VL SJ3 NS TKLEXT CLK"
    ::irc::send "PASS $::irc::password"
    ::irc::send "SERVER $::irc::servername 1 :U2310-Fh6XiOoEe-$::irc::numeric UnrealIRCD Service Framework V.$::irc::version"
    ::irc::bot_init $::irc::nick $::irc::username $::irc::hostname $::irc::realname
    ::irc::send "NETINFO 0 [::tools::unixtime] 2310 * 0 0 0 :$::irc::netname"
    ::irc::send "EOS"
    return 0
  }

  #<<< PING :irc1.hebeo.fr
  if {[lindex $arg 0]=="PING"} {
    fsend $sock "PONG $::irc::servername [lindex $arg 1]"; return 0
  }
  #<<< PASS :tclpur
  if {[lindex $arg 0]=="PASS"} {
    set recv_pass [string range [lindex $arg 1] 1 end]
    if {[::tools::testcs $::irc::password $recv_pass]} {
      if {$::debug==1} { puts "Received password is OK !" }
    } else {
      puts "Received password is not OK ! Link abort !"
      close $::irc::sock
      exit 0
    }
  }
  #<<< SERVER irc1.hebeo.fr 1 :U2310-Fhin6XeOoE-1 Hebeo irc1 server
  if {[lindex $arg 0]=="SERVER"} {
    set hubname [lindex $arg 1]
    set numeric [lindex $arg 2]
    set description [lrange $arg 4 end]
    if {[::tools::testcs $hubname $::irc::hub]} {
      if {$::debug==1} { puts "Received hubname is OK !" }
      set ::irc::srvname2num($numeric) $hubname
    } else {
      puts "Received hubname is not OK ! Link abort !"
      close $::irc::sock
      exit 0
    }
  }
  #<<< NETINFO 5 1326465580 2310 MD5:4609f507a584411d7327af344c3ef61c 0 0 0 :Hebeo
  if {[lindex $arg 0]=="NETINFO"} {
    #set maxglobal [lindex $arg 1]
    set hubtime [lindex $arg 2]
    set currtime [::tools::unixtime]
    set netname "[string range [lrange $arg 8 end] 1 end]"
    if {$hubtime != $currtime} {
      puts "Cloak are not sync. Difference is [expr $currtime - $hubtime] seconds."
    }
    if {![::tools::testcs $netname $::irc::netname]} {
      puts "Received network name doesn't correspond to given network name in configuration. I have received $netname but I am waiting for $::irc::netname. Abort link."
      ::irc::send ":$::irc::servername SQUIT $::irc::hub :Configuration error."
      close $::irc::sock
      exit 0
    } else {
      ::tools::write_pid $mysock(pid)
    }
  }

  #<<< NICK Yume       1 1326268587 chaton 192.168.42.1 1 0 +iowghaAxNz * 851AC590.11BF4B94.149A40B0.IP :Structure of Body
  #<<< NICK GameServer 1 1326702996 tclsh  tcl.hebeo.fr g 0 +oSqB       * heb1-EAB106C8.hebeo.fr        :TCL GameServer Controller
  if {[lindex $arg 0]=="NICK"} {
    set nickname [lindex $arg 1]
    #set hopcount [lindex $arg 2]
    #set timestamp [lindex $arg 3]
    #set ident [lindex $arg 4]
    #set realhost [lindex $arg 5]
    set numeric [lindex $arg 6]
    #set servicestamp [lindex $arg 7]
    #set umodes [lindex $arg 8]
    #set cloakhost [lindex $arg 9]
    #set vhost [lindex $arg 10]
    #set gecos [string range [lrange $arg 11 end] 1 end]
    lappend ::irc::userlist $nickname
    set ::irc::userlist [::tools::nodouble $::irc::userlist]
    lappend ::irc::users($::irc::srvname2num([::tools::base2dec $numeric $::tools::ub64chars])) $nickname
    set ::irc::users($::irc::srvname2num([::tools::base2dec $numeric $::tools::ub64chars])) [::tools::nodouble $::irc::users($::irc::srvname2num([::tools::base2dec $numeric $::tools::ub64chars]))]
  }
  #<<< :Yume NICK Yuki 1326485191
  if {[lindex $arg 1]=="NICK"} {
    set oldnick [string range [lindex $arg 0] 1 end]
    set newnick [lindex $arg 2]
    #set timestamp [lindex $arg 3]
    set ::irc::userlist [::tools::llreplace $::irc::userlist $oldnick $newnick]
    foreach arr [array names ::irc::users *] {
      set ::irc::users($arr) [::tools::llreplace $::irc::users($arr) $oldnick $newnick]
    }
  }

  #<<< :Yume UMODE2 +oghaAN
  if {[lindex $arg 1]=="UMODE2"} {
    # not in use
  }
  #<<< @10 SVS2MODE Poker-egg +d 1
  if {[lindex $arg 1]=="SVS2MODE"} {
    # not in use
  }

  #<<< :s220nov8kjwu9p9 QUIT :Client exited
  #<<< :Poker-egg QUIT :\[irc1.hebeo.fr\] Local kill by Yume (calin :D)
  if {[lindex $arg 1]=="QUIT"} {
    set nickname [string range [lindex $arg 0] 1 end]
    #set reason [string range [lrange $arg 2 end] 1 end]
    set ::irc::userlist [::tools::lremove $::irc::userlist $nickname]
    foreach arr [array names ::irc::users *] {
      set ::irc::users($arr) [::tools::lremove $::irc::users($arr) $nickname]
    }
  }

  #<<< :Yume KILL Poker-egg :851AC590.11BF4B94.149A40B0.IP!Yume (salope)
  if {[lindex $arg 1]=="KILL"} {
    #set killer [string range [lindex $arg 0] 1 end]
    set nickname [lindex $arg 2]
    #set path [string range [lindex $arg 3] 1 end]
    #set reason [string range [lrange $arg 4 end] 1 end-1]
    set ::irc::userlist [::tools::lremove $::irc::userlist $nickname]
    foreach arr [array names ::irc::users *] {
      set ::irc::users($arr) [::tools::lremove $::irc::users($arr) $nickname]
    }
    if {[lindex $arg 2]==$::irc::nick} {
      bot_init $::irc::nick $::irc::username $::irc::hostname $::irc::realname
    }
  }

  #SETHOST
  #CHGHOST

  #SETIDENT
  #CHGIDENT

  #SETNAME
  #CHGNAME

  #<<< :Yume WHOIS Uno :uno
  if {[lindex $arg 1]=="WHOIS"} {
    set source [string range [lindex $arg 0] 1 end]
    set target [string range [lindex $arg 3] 1 end]
    if {[lsearch [string tolower $::irc::botlist] [string tolower $target]]<0} { return }
    ::irc::send ":$::irc::nick PRIVMSG $::irc::adminchan :[::msgcat::mc cont_whois0 $source $target]"
    ::irc::send ":$::irc::nick NOTICE $source :[::msgcat::mc cont_whois1 $target]"
    #fsend $mysock(sock) ":$target 320 whois is not implemented."
    #fsend $mysock(sock) ":$target 318 :End of /WHOIS list."
  }

  #<<< @1 SERVER irc2.hebeo.fr 2 2   :Hebeo irc1 server
  #<<< @1 SERVER irc2.hebeo.fr 2 131 :Hebeo irc2 server
  # Introducing distant server by hub
  if {[lindex $arg 1]=="SERVER"} {
    #set srcnumeric [string range [lindex $arg 0] 1 end]
    set servername [lindex $arg 2]
    #set hopcount [lindex $arg 3]
    set numeric [lindex $arg 4]
    #set description [string range [lrange $arg 5 end] 1 end]
    set network(servername-$numeric) $servername
    if {$::debug==1} {
      puts "Adding server numeric $numeric for server $servername."
    }
  }

  #<<< SQUIT irc2.hebeo.fr :Yume
  if {[lindex $arg 0]=="SQUIT"} {
    set servername [lindex $arg 1]
    #set reason [string range [lrange $arg 2 end] 1 end]
    foreach user $::irc::users([string tolower $servername]) {
      set ::irc::userlist [::tools::lremove $::irc::userlist $user]
      foreach arr [array names ::irc::users *] {
        set ::irc::users($arr) [::tools::lremove $::irc::users($arr) $user]
      }
    }
  }

  #SDESC

  #STATS


  #<<< @1 SJOIN 1325144112 #Poker :Yume 
  if {[lindex $arg 1]=="SJOIN"} {
    #set numeric [string range [lindex $arg 0] 1 end]
    #set timestamp [lindex $arg 2]
    set chan [lindex $arg 3]
    set nicks [lindex [split $arg :] 1]
    #set nick [string range [lindex $arg 4] 1 end]
    foreach nick [string tolower $nicks] {
      if {![string is alnum [string index $nick 0]]} { continue }
      lappend ::irc::users($chan) $nick
      set ::irc::users($chan) [::tools::nodouble $::irc::users($chan)]
      lappend ::irc::chanlist $chan
      set ::irc::chanlist [::tools::nodouble $::irc::chanlist]
      # Hooks for global join
      if {[info exists ::irc::hook(join)]} { foreach hookj $::irc::hook(join) { $hookj $nick $chan } }
      # Hooks for specific join on a chan
      if {[info exists ::irc::hook(join-[string tolower $chan])]} { $::irc::hook(join-[string tolower $chan]) $nick }
    }
  }
  #<<< :Yume JOIN #blabla,#opers
  if {[lindex $arg 1]=="JOIN"} {
    set nick [string range [lindex $arg 0] 1 end]
    set chans [join [split [lindex $arg 2] ,]]
    foreach chan [string tolower $chans] {
      lappend ::irc::users($chan) $nick
      set ::irc::users($chan) [::tools::nodouble $::irc::users($chan)]
      lappend ::irc::chanlist $chan
      set ::irc::chanlist [::tools::nodouble $::irc::chanlist]
      # Hooks for global join
      if {[info exists ::irc::hook(join)]} { foreach hookj $::irc::hook(join) { $hookj $nick $chan } }
      # Hooks for specific join on a chan
      if {[info exists ::irc::hook(join-[string tolower $chan])]} { $::irc::hook(join-[string tolower $chan]) $nick }
    }
  }

  #<<< :Yume PART #Poker
  if {[lindex $arg 1]=="PART"} {
    set nick [string range [lindex $arg 0] 1 end]
    set chan [join [lindex $arg 2]]
    foreach chan [string tolower $chans] {
      lappend ::irc::users($chan) $nick
      set ::irc::users($chan) [::tools::nodouble $::irc::users($chan)]
      lappend ::irc::chanlist $chan
      set ::irc::chanlist [::tools::nodouble $::irc::chanlist]
      # Hooks for global part
      if {[info exists ::irc::hook(part)]} { foreach hookj $::irc::hook(part) { $hookj $nick $chan } }
      # Hooks for specific part on a chan
      if {[info exists ::irc::hook(part-[string tolower $chan])]} { $::irc::hook(part-[string tolower $chan]) $nick }
  }
  
  # PRIVMSG
  if {[lindex $arg 1]=="PRIVMSG"} {
    set from [string range [lindex $arg 0] 1 end]
    set to [lindex $arg 2]
    set commc [list [string range [lindex $arg 3] 1 end] [lrange $arg 4 end]]
    set comm [::tools::stripmirc $commc]

    # Hooks for global PRIVMSG
    if {$::debug==1} {
      puts "First char of \$to is [string index $to 0]"
      puts "::irc::hook(privmsgchan) exist ? [info exists ::irc::hook(privmsgchan)]"
    }
    if {([string index $to 0]=="#") && ([info exists ::irc::hook(privmsgchan)])} {
      if {$::debug==1} { puts "Entering global privmsg hook for $from $to $comm" }
      foreach hookp $::irc::hook(privmsgchan) {
        if {$::debug==1} { puts "Calling hook $hookp" }
        $hookp $from $to "$commc"
      }
    }
    # Hook for PRIVMSG to specific chan or user
    if {[info exists ::irc::hook(privmsg-[string tolower $to])]} { foreach hookp $::irc::hook(privmsg-[string tolower $to]) { $hookp $from "$commc" } }

    if {[::irc::is_admin $from] && [test [string index [lindex $comm 0] 0] $::irc::cmdchar]} {
      switch [string range [lindex $comm 0] 1 end] {
        rehash {
          ::irc::my_rehash
          ::irc::send ":$::irc::nick PRIVMSG $::irc::adminchan :[::msgcat::mc cont_rehash $from]"
        }
        source {
          source $comm
          ::irc::send ":$::irc::nick PRIVMSG $::irc::adminchan :[::msgcat::mc cont_source $comm $from]"
        }
        die {
          ::irc::send ":$::irc::servername SQUIT $::irc::hub :[::msgcat::mc cont_shutdown $from]"
          close $::irc::sock
          exit 0
        }
      }
    }
    return 0
  }
  if {[lindex $arg 1]=="KICK"} {
    set to [lindex $arg 2]
    if {[lindex $arg 3]==$::irc::nick} {
      join_chan $::irc::nick $to
    }
  }
}

if {$service=="0"} { puts [::msgcat::mc cont_netconn]; ::irc::socket_connect; set service 1 }
