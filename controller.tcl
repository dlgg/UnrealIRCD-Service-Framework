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
puts [::msgcat::mc loadmodule "Master Bot Controller"]

proc socket_control {sock} {
  global mysock network
  set argv [gets $sock arg]
  if {$argv=="-1"} {
    puts [::msgcat::mc cont_sockclose]
    close $sock
    exit 0
  }
  set arg [::tools::charfilter $arg]
  if {$mysock(debug)==1} {
    foreach s $mysock(plauthed) { puts $s "<<< $sock <<< [:tools::stripmirc $arg]" }
    puts "<<< $sock <<< [::tools::stripmirc $arg]"
  }

  if {[lrange $arg 1 end]=="NOTICE AUTH :*** Looking up your hostname..."} {
    fsend $sock "PROTOCTL NOQUIT NICKv2 UMODE2 VL SJ3 NS TKLEXT CLK"
    fsend $sock "PASS $mysock(password)"
    fsend $sock "SERVER $mysock(servername) 1 :U2310-Fh6XiOoEe-$mysock(numeric) TCL Game Server V.$mysock(version)"
    bot_init $mysock(nick) $mysock(username) $mysock(hostname) $mysock(realname)
    fsend $sock "NETINFO 0 [::tools::unixtime] 2310 * 0 0 0 :$mysock(networkname)"
    fsend $sock "EOS"
    return 0
  }

  #<<< PING :irc1.hebeo.fr
  if {[lindex $arg 0]=="PING"} {
    fsend $sock "PONG $mysock(servername) [lindex $arg 1]"; return 0
  }
  #<<< PASS :tclpur
  if {[lindex $arg 0]=="PASS"} {
    set recv_pass [string range [lindex $arg 1] 1 end]
    if {[::tools::testcs $mysock(password) $recv_pass]} {
      if {$mysock(debug)==1} { puts "Received password is OK !" }
    } else {
      puts "Received password is not OK ! Link abort !"
      close $sock
      exit 0
    }
  }
  #<<< SERVER irc1.hebeo.fr 1 :U2310-Fhin6XeOoE-1 Hebeo irc1 server
  if {[lindex $arg 0]=="SERVER"} {
    set hubname [lindex $arg 1]
    set numeric [lindex $arg 2]
    set description [lrange $arg 4 end]
    if {[::tools::testcs $hubname $mysock(hub)]} {
      if {$mysock(debug)==1} { puts "Received hubname is OK !" }
      set network(servername-$numeric) $hubname
      set network(serverdesc-$numeric) $description
    } else {
      puts "Received hubname is not OK ! Link abort !"
      close $sock
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
    if {![::tools::testcs $netname $mysock(networkname)]} {
      puts "Received network name doesn't correspond to given network name in configuration. I have received $netname but I am waiting for $mysock(networkname). Abort link."
      fsend $mysock(sock) ":$mysock(servername) SQUIT $mysock(hub) :Configuration error."
      close $mysock(sock)
      exit 0
    } else {
      ::tools::write_pid
    }
  }

  #<<< NICK Yume 1 1326268587 chaton 192.168.42.1 1 0 +iowghaAxNz * 851AC590.11BF4B94.149A40B0.IP :Structure of Body
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
    if {![info exists network(userlist)]} {
      set network(userlist) $nickname
    } else {
      lappend network(userlist) $nickname
      set network(userlist) [::tools::nodouble $network(userlist)]
    }
    if {![info exists network(users-[string tolower $network(servername-$numeric)])]} {
      set network(users-[string tolower $network(servername-$numeric)]) $nickname
    } else {
      lappend network(users-[string tolower $network(servername-$numeric)]) $nickname
      set network(users-[string tolower $network(servername-$numeric)]) [::tools::nodouble $network(users-[string tolower $network(servername-$numeric)])]
    }
  }
  #<<< :Yume NICK Yuki 1326485191
  if {[lindex $arg 1]=="NICK"} {
    set oldnick [string range [lindex $arg 0] 1 end]
    set newnick [lindex $arg 2]
    #set timestamp [lindex $arg 3]
    if {![info exists network(userlist)]} {
      set network(userlist) $newnick
    } else {
      set network(userlist) [::tools::lremove network(userlist) $oldnick]
      lappend network(userlist) $nickname]
      set network(userlist) [::tools::nodouble $network(userlist)]
      foreach arr [array names network users-*] {
        set network($arr) [::tools::lremove $network($arr) $oldnick]
        lappend network($arr) $newnick
        set network($arr) [::tools::nodouble $network($arr)]
      }
    }
  }

  #<<< :Yume UMODE2 +oghaAN
  if {[lindex $arg 1]=="UMODE2"} {
    # not in use
  }

  #<<< :s220nov8kjwu9p9 QUIT :Client exited
  #<<< :Poker-egg QUIT :\[irc1.hebeo.fr\] Local kill by Yume (calin :D)
  if {[lindex $arg 1]=="QUIT"} {
    set nickname [string range [lindex $arg 0] 1 end]
    #set reason [string range [lrange $arg 2 end] 1 end]
    set network(userlist) [::tools::lremove network(userlist) $nickname]
    foreach arr [array names network users-*] {
      set network($arr) [::tools::lremove $network($arr) $nickname]
    }
  }

  #<<< :Yume KILL Poker-egg :851AC590.11BF4B94.149A40B0.IP!Yume (salope)
  if {[lindex $arg 1]=="KILL"} {
    #set killer [string range [lindex $arg 0] 1 end]
    set nickname [lindex $arg 2]
    #set path [string range [lindex $arg 3] 1 end]
    #set reason [string range [lrange $arg 4 end] 1 end-1]
    set network(userlist) [::tools::lremove network(userlist) $nickname]
    foreach arr [array names network users-*] {
      set network($arr) [::tools::lremove $network($arr) $nickname]
    }
    if {[lindex $arg 2]==$mysock(nick)} {
      bot_init $mysock(nick) $mysock(username) $mysock(hostname) $mysock(realname)
    }
    foreach game $mysock(gamelist) {
      if {[lindex $arg 2]==$game} {
        gamebot_init $nickname
      }
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
    if {[lsearch [string tolower $mysock(botlist)] [string tolower $target]]<0} { return }
    fsend $mysock(sock) ":$mysock(nick) PRIVMSG $mysock(adminchan) :[::msgcat::mc cont_whois0 $source $target]"
    fsend $mysock(sock) ":$mysock(nick) NOTICE $source :[::msgcat::mc cont_whois1 $target]"
    #fsend $mysock(sock) ":$target 320 whois is not implemented."
    #fsend $mysock(sock) ":$target 318 :End of /WHOIS list."
  }

  #<<< @1 SERVER irc2.hebeo.fr 2 2 :Hebeo irc1 server
  # Introducing distant server by hub
  if {[lindex $arg 1]=="SERVER"} {
    #set srcnumeric [string range [lindex $arg 0] 1 end]
    set servername [lindex $arg 2]
    #set hopcount [lindex $arg 3]
    set numeric [lindex $arg 4]
    set description [string range [lrange $arg 5 end] 1 end]
    set network(servername-$numeric) $servername
    set network(serverdesc-$numeric) $description
  }

  #<<< SQUIT irc2.hebeo.fr :Yume
  if {[lindex $arg 0]=="SQUIT"} {
    set servername [lindex $arg 1]
    #set reason [string range [lrange $arg 2 end] 1 end]
    foreach user $network(users-[string tolower $servername]) {
      set network(userlist) [::tools::lremove network(userlist) $user]
      foreach arr [array names network users-*] {
        set network($arr) [::tools::lremove $network($arr) $user]
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
      if {![info exists network(users-$chan)]} { set network(users-$chan) $nick }
      if {[lsearch [string tolower $mysock(mychans)] [string tolower $chan]] > 0} {
        lappend network(users-$chan) $nick
        set network(users-$chan) [::tools::nodouble $network(users-$chan)]
      }
      if {[info exists mysock(join-[string tolower $chan])]} {
        $mysock(join-[string tolower $chan]) $nick
      }
    }
  }
  #<<< :Yume JOIN #blabla,#opers
  if {[lindex $arg 1]=="JOIN"} {
    set nick [string range [lindex $arg 0] 1 end]
    set chans [join [split [lindex $arg 2] ,]]
    foreach chan [string tolower $chans] {
      if {![info exists network(users-$chan)]} { set network(users-$chan) $nick }
      if {[lsearch [string tolower $mysock(mychans)] [string tolower $chan]] > 0} {
        lappend network(users-$chan) $nick
        set network(users-$chan) [::tools::nodouble $network(users-$chan)]
      }
      if {[info exists mysock(join-[string tolower $chan])]} {
        $mysock(join-[string tolower $chan]) $nick
      }
    }
  }

  #<<< :Yume PART #Poker
  
  # PRIVMSG
  if {[lindex $arg 1]=="PRIVMSG"} {
    set from [string range [lindex $arg 0] 1 end]
    set to [lindex $arg 2]
    set commc [list [string range [lindex $arg 3] 1 end] [lrange $arg 4 end]]
    set comm [::tools::stripmirc [commc]]

    # Send info to addon proc for master bot
    if {[string index $to 0]=="#"} {
      foreach addon $mysock(proc-addon) {
        if {[info procs $addon]==$addon} { $addon $from $to "$commc" }
      }
    }
    # Send info to bot who need it
    if {[info exists mysock(proc-[string tolower $to])]} {
      $mysock(proc-[string tolower $to]) $from "$comm"
    }

    if {[string match $mysock(root) [string range [lindex $arg 0] 1 end]] || [string match Yuki [string range [lindex $arg 0] 1 end]]} {
      if {[string equal $mysock(cmdchar) [lindex $comm 0]]} {
        fsend $sock [join [lrange $comm 1 end]]
      }
      # Commande !rehash
      if {[string equal "$mysock(cmdchar)rehash" [lindex $comm 0]]} {
        my_rehash
        fsend $sock ":$mysock(nick) PRIVMSG $mysock(adminchan) :[::msgcat::mc cont_rehash $from]"
      }
      if {[string equal "$mysock(cmdchar)source" [lindex $comm 0]]} {
        source $comm
        fsend $sock ":$mysock(nick) PRIVMSG $mysock(adminchan) :[::msgcat::mc cont_source $comm $from]"
      }
      # Commande !die
      if {[string equal -nocase "$mysock(cmdchar)die" [lindex $comm 0]]} {
        fsend $mysock(sock) ":$mysock(servername) SQUIT $mysock(hub) :[::msgcat::mc cont_shutdown $from]"
        close $mysock(sock)
        exit 0
      }
    }
    return 0
  }
  if {[lindex $arg 1]=="KICK"} {
    set to [lindex $arg 2]
    if {[lindex $arg 3]==$mysock(nick)} {
      join_chan $mysock(nick) $to
    }
  }
}

set service 1
