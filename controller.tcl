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

  switch [lindex $arg 0] {
    PING {
    #<<< PING :irc1.hebeo.fr
      ::irc::send "PONG $::irc::servername [lindex $arg 1]"; return
    }
    PASS {
    #<<< PASS :tclpur
      set recv_pass [string range [lindex $arg 1] 1 end]
      if {[::tools::testcs $::irc::password $recv_pass]} {
        if {$::debug==1} { puts "Received password is OK !" }
      } else {
        puts "Received password is not OK ! Link abort ! I have received $recv_pass but i am waiting for $::irc::password"
        close $::irc::sock
        exit 0
      }
      return
    }
    SERVER {
    #<<< SERVER irc1.hebeo.fr 1 :U2310-Fhin6XeOoE-1 Hebeo irc1 server
      set hubname [lindex $arg 1]
      set numeric [lindex $arg 2]
      set description [lrange $arg 4 end]
      if {[::tools::testcs $hubname $::irc::hub]} {
        if {$::debug==1} { puts "Received hubname is OK !" }
        set ::irc::srvname2num($numeric) $hubname
        return
      } else {
        puts "Received hubname is not OK ! Link abort !"
        close $::irc::sock
        exit 0
      }
    }
    NETINFO {
    #<<< NETINFO 5 1326465580 2310 MD5:4609f507a584411d7327af344c3ef61c 0 0 0 :Hebeo
      #set maxglobal [lindex $arg 1]
      set hubtime [lindex $arg 2]
      set currtime [::tools::unixtime]
      set netname "[string range [lrange $arg 8 end] 1 end]"
      if {$hubtime != $currtime} { puts "Cloak are not sync. Difference is [expr $currtime - $hubtime] seconds." }
      if {![::tools::testcs $netname $::irc::netname]} {
        puts "Received network name doesn't correspond to given network name in configuration. I have received $netname but I am waiting for $::irc::netname. Abort link."
        ::irc::send ":$::irc::servername SQUIT $::irc::hub :Configuration error."
        close $::irc::sock
        exit 0
      } else {
        ::tools::write_pid $::irc::pid
        return
      }
    }
    NICK {
    #<<< NICK Yume       1 1326268587 chaton 192.168.42.1 1 0 +iowghaAxNz * 851AC590.11BF4B94.149A40B0.IP :Structure of Body
    #<<< NICK GameServer 1 1326702996 tclsh  tcl.hebeo.fr g 0 +oSqB       * heb1-EAB106C8.hebeo.fr        :TCL GameServer Controller
      set nickname [lindex $arg 1]
      #set hopcount [lindex $arg 2]
      #set timestamp [lindex $arg 3]
      #set ident [lindex $arg 4]
      #set realhost [lindex $arg 5]
      set numeric [lindex $arg 6]
      #set servicestamp [lindex $arg 7]
      set umodes [lindex $arg 8]
      #set cloakhost [lindex $arg 9]
      #set vhost [lindex $arg 10]
      #set gecos [string range [lrange $arg 11 end] 1 end]
      lappend ::irc::userlist $nickname
      set ::irc::userlist [::tools::nodouble $::irc::userlist]
      lappend ::irc::users($::irc::srvname2num([::tools::base2dec $numeric $::tools::ub64chars])) $nickname
      set ::irc::users($::irc::srvname2num([::tools::base2dec $numeric $::tools::ub64chars])) [::tools::nodouble $::irc::users($::irc::srvname2num([::tools::base2dec $numeric $::tools::ub64chars]))]
      ::irc::parse_umodes $nickname $umodes
      return
    }
    SQUIT {
    #<<< SQUIT irc2.hebeo.fr :Yume
    # TODO : remove srvname2num($numeric) corresponding to server
      set servername [lindex $arg 1]
      #set reason [string range [lrange $arg 2 end] 1 end]
      foreach user $::irc::users([string tolower $servername]) {
        ::irc::user_quit $user
      }
      unset ::irc::users([string tolower $servername])
      return
    }
  }
  # End of switch [lindex $arg 0]

###
###
###

  switch [lindex $arg 1] {
    PRIVMSG {
    # PRIVMSG
      set from [string range [lindex $arg 0] 1 end]
      set to [lindex $arg 2]
      set commc [list [string range [lindex $arg 3] 1 end] [lrange $arg 4 end]]
      set comm [::tools::stripmirc $commc]
      # Hooks for global PRIVMSG
      if {$::debug==1} { puts "First char of \$to is [string index $to 0]"; puts "::irc::hook(privmsgchan) exist ? [info exists ::irc::hook(privmsgchan)]" }
      if {([string index $to 0]=="#") && ([info exists ::irc::hook(privmsgchan)])} {
        if {$::debug==1} { puts "Entering global privmsg hook for $from $to $comm. Hooks are : $::irc::hook(privmsgchan)" }
        foreach hookp $::irc::hook(privmsgchan) {
          if {$::debug==1} { puts "Calling hook $hookp" }
          $hookp $from $to "$commc"
        }
      }
      # Hook for PRIVMSG to specific chan or user
      if {[info exists ::irc::hook(privmsg-[string tolower $to])]} { foreach hookp $::irc::hook(privmsg-[string tolower $to]) { $hookp $from "$commc" } }
      # Some admins commands to manage the service
      if {[::irc::is_admin $from] && [::tools::test [string index [lindex $comm 0] 0] $::irc::cmdchar]} {
        switch [string range [lindex $comm 0] 1 end] {
          rehash { ::irc::rehash ; ::irc::send ":$::irc::nick PRIVMSG $::irc::adminchan :[::msgcat::mc cont_rehash $from]" }
          source { source [lindex $comm 1]; ::irc::send ":$::irc::nick PRIVMSG $::irc::adminchan :[::msgcat::mc cont_source $comm $from]" }
          die { ::irc::send ":$::irc::servername SQUIT $::irc::hub :[::msgcat::mc cont_shutdown $from]"; close $::irc::sock; exit 0 }
        }
      }
      return
    }
    NICK {
    #<<< :Yume NICK Yuki 1326485191
      set oldnick [string range [lindex $arg 0] 1 end]
      set newnick [lindex $arg 2]
      #set timestamp [lindex $arg 3]
      set ::irc::userlist [::tools::llreplace $::irc::userlist $oldnick $newnick]
      set ::irc::regusers [::tools::llreplace $::irc::regusers $oldnick $newnick]
      foreach arr [array names ::irc::users *] { set ::irc::users($arr) [::tools::llreplace $::irc::users($arr) $oldnick $newnick] }
      return
    }
    MODE {
    # :user MODE user +/-xxxx
      #set nick [lindex $arg 2]
      #set modes [lindex $arg 3]
      set source [lindex $arg 2]
      set target [lindex $arg 2]
      set modes [lindex $arg 3]
      [is_chan $target] { return } { ::irc::parse_umodes $nick $modes }
      return
    }
    UMODE2 {
    #<<< :Yume UMODE2 +oghaAN
    #<<< :Yume UMODE2 +owghaANqHp
      set nick [string range [lindex $arg 0] 1 end]
      set modes [lindex $arg 2]
      ::irc::parse_umodes $nick $modes
      return
    }
    SVS2MODE {
    #<<< @10 SVS2MODE Poker-egg +d 1
    #<<< @10 SVS2MODE Yuki -r+d 1
    #<<< @10 SVS2MODE Yume +rd 1327415440
      set nick [lindex $arg 2]
      set modes [lindex $arg 3]
      #set timestamp [lindex $arg 4]
      ::irc::parse_umodes $nick $modes
      return
    }
    QUIT {
    #<<< :s220nov8kjwu9p9 QUIT :Client exited
    #<<< :Poker-egg QUIT :\[irc1.hebeo.fr\] Local kill by Yume (calin :D)
      set nickname [string range [lindex $arg 0] 1 end]
      set reason [string range [lrange $arg 2 end] 1 end]
      # Hooks for quit
      if {[info exists ::irc::hook(quit)]} { foreach hookj $::irc::hook(quit) { $hookj $nickname $reason } }
      ::irc::user_quit $nickname
      return
    }
    KILL {
    #<<< :Yume KILL Poker-egg :851AC590.11BF4B94.149A40B0.IP!Yume (salope)
      #set killer [string range [lindex $arg 0] 1 end]
      set nickname [lindex $arg 2]
      #set path [string range [lindex $arg 3] 1 end]
      set reason [string range [lrange $arg 4 end] 1 end-1]
      # Hooks for kill
      if {[info exists ::irc::hook(kill)]} { foreach hookj $::irc::hook(kill) { $hookj $nickname $reason } }
      ::irc::user_quit $nickname
      if {[lindex $arg 2]==$::irc::nick} { bot_init $::irc::nick $::irc::username $::irc::hostname $::irc::realname }
      return
    }
    SETHOST {
      # not in use
      return
    }
    CHGHOST {
      # not in use
      return
    }
    SETIDENT {
      # not in use
      return
    }
    CHGIDENT {
      # not in use
      return
    }
    SETNAME {
      # not in use
      return
    }
    CHGNAME {
      # not in use
      return
    }
    WHOIS {
    #<<< :Yume WHOIS Uno :uno
      set source [string range [lindex $arg 0] 1 end]
      set target [string range [lindex $arg 3] 1 end]
      if {[lsearch [string tolower $::irc::botlist] [string tolower $target]]<0} { return }
      ::irc::send ":$::irc::nick PRIVMSG $::irc::adminchan :[::msgcat::mc cont_whois0 $source $target]"
      ::irc::send ":$::irc::nick NOTICE $source :[::msgcat::mc cont_whois1 $target]"
      #::irc::send ":$target 320 whois is not implemented."
      #::irc::send ":$target 318 :End of /WHOIS list."
      return
    }
    SWHOIS {
    #<<< @1 SWHOIS Yume :a trouve le passe de la oline magique
      # not in use
      return
    }
    SERVER {
    #<<< @1 SERVER irc2.hebeo.fr 2 2   :Hebeo irc1 server
    #<<< @1 SERVER irc2.hebeo.fr 2 131 :Hebeo irc2 server
    # Introducing dh istant server by hub
      #set srcnumeric [string range [lindex $arg 0] 1 end]
      set servername [lindex $arg 2]
      #set hopcount [lindex $arg 3]
      set numeric [lindex $arg 4]
      #set description [string range [lrange $arg 5 end] 1 end]
      set ::irc::srvname2num($numeric) $servername
      if {$::debug==1} { puts "Adding server numeric $numeric for server $servername." }
      return
    }
    SDESC {
      # not in use
      return
    }
    STATS {
      # not in use
      return
    }
    SJOIN {
    #<<< @1 SJOIN 1325144112 #Poker :Yume 
      #set numeric [string range [lindex $arg 0] 1 end]
      #set timestamp [lindex $arg 2]
      set chan [lindex $arg 3]
      set nicks [lindex [split $arg :] 1]
      #set nick [string range [lindex $arg 4] 1 end]
      foreach nick [string tolower $nicks] {
        # Hooks for global join
        if {[info exists ::irc::hook(join)]} { foreach hookj $::irc::hook(join) { $hookj $nick $chan } }
        # Hooks for specific join on a chan
        if {[info exists ::irc::hook(join-[string tolower $chan])]} { $::irc::hook(join-[string tolower $chan]) $nick }
        if {![string is alnum [string index $nick 0]]} { continue }
        # Updating global variables
        lappend ::irc::users($chan) $nick
        set ::irc::users($chan) [::tools::nodouble $::irc::users($chan)]
        lappend ::irc::chanlist $chan
        set ::irc::chanlist [::tools::nodouble $::irc::chanlist]
      }
    }
    JOIN {
    #<<< :Yume JOIN #blabla,#opers
      set nick [string range [lindex $arg 0] 1 end]
      set chans [join [split [lindex $arg 2] ,]]
      foreach chan [string tolower $chans] {
        # Hooks for global join
        if {[info exists ::irc::hook(join)]} { foreach hookj $::irc::hook(join) { $hookj $nick $chan } }
        # Hooks for specific join on a chan
        if {[info exists ::irc::hook(join-[string tolower $chan])]} { $::irc::hook(join-[string tolower $chan]) $nick }
        # Updating global variables
        ::irc::userjoin $nick $chan
      }
      return
    }
    PART {
    #<<< :Yume PART #Poker
    #<<< :Yume PART #test :bla bla ?
      set nick [string range [lindex $arg 0] 1 end]
      set chan [join [lindex $arg 2]]
      set reason "[string range [lindex $arg 3 end] 1 end]"
      # Hooks for global part
      if {[info exists ::irc::hook(part)]} { foreach hookj $::irc::hook(part) { $hookj $nick $chan $reason } }
      # Hooks for specific part on a chan
      if {[info exists ::irc::hook(part-[string tolower $chan])]} { $::irc::hook(part-[string tolower $chan]) $nick $reason }
      # Updating global variables
      ::irc::user_part $nick $chan
      return
    }
    KICK {
      set to [lindex $arg 2]
      if {[lindex $arg 3]==$::irc::nick} { join_chan $::irc::nick $to }
      return
    }

  }
  # End of switch [lindex $arg 1]

  
}

