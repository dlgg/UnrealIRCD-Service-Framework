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
puts [::msgcat::mc loadmodule "Master Bot Controller"]

[info exists service] { } { set service 0 }

proc ::irc::socket_control {} {
  if {[catch {set argv [gets $::irc::sock rawarg]} error]} { puts [::msgcat::mc sockerror $error]); after $::irc::reconnect; ::irc::socket_connect; return 0 }
  if {$argv=="-1"} {
    puts [::msgcat::mc cont_sockclose]
    close $::irc::sock
    after $::irc::reconnect
    ::irc::socket_connect
  }
  set arg [::tools::charfilter $rawarg]
  if {$::debug} {
    set ncarg [::tools::stripmirc $arg]
    puts "<<< IRC <<< $ncarg"
  }
  #if {[lrange $arg 1 end]=="NOTICE AUTH :*** Looking up your hostname..."} { ::irc::netsync; return }

  switch [lindex $arg 0] {
    8 -
    PING {
    #<<< PING :irc1.hebeo.fr
      ::irc::send "[tok PONG] $::irc::servername [lindex $arg 1]"; ::irc::reset_timeout; return
    }
    PASS {
    #<<< PASS :tclpur
      set recv_pass [string range [lindex $arg 1] 1 end]
      if {[::tools::testcs $::irc::password $recv_pass]} {
        if {$::debug} { puts "Received password is OK !" }
      } else {
        puts "Received password is not OK ! Link abort ! I have received $recv_pass but I am waiting for $::irc::password"
        close $::irc::sock
        exit 0
      }
      return
    }
    SERVER {
    #<<< SERVER irc1.hebeo.fr 1 :U2310-Fhin6XeOoE-1 Hebeo irc1 server
      set hubname [lindex $arg 1]
      #set hop [lindex $arg 2]
      set unrealversion [string range [lindex $arg 3] 2 5]
      set numeric [lindex [split [lindex $arg 3] '-'] 2]
      set description [lrange $arg 4 end]
      if {![::tools::test $unrealversion $::irc::uversion]} {
        puts "Received Unreal Version is not OK ! Link abort ! I have received $unrealversion but I am waiting for $::irc::uversion"
        close $::irc::sock
        exit 0
      }
      if {![::tools::testcs $hubname $::irc::hub]} {
        puts "Received hubname is not OK ! Link abort ! I have received $hubname but I am waiting for $::irc::hub"
        close $::irc::sock
        exit 0
      }
      if {$::debug} { puts "Received hubname and unreal version is OK !" }
      set ::irc::srvname2num($numeric) $hubname
      set ::irc::srvname2num($hubname) $numeric
      return
    }
    AO -
    NETINFO {
    #<<< NETINFO 5 1326465580 2310 MD5:4609f507a584411d7327af344c3ef61c 0 0 0 :Hebeo
      #set maxglobal [lindex $arg 1]
      set hubtime [lindex $arg 2]
      set currtime [::tools::unixtime]
      set netname "[string range [lrange $arg 8 end] 1 end]"
      if {$hubtime != $currtime} {
        set diff [expr $currtime - $hubtime]
        puts "Cloak are not sync. Difference is $diff seconds."
        if {$diff <= 30} {
          ::irc::send "$::irc::servername [tok TSCTL] OFFSET [string range $diff 0 1] [string range $diff 1 [string length $diff]]"
          puts "Cloak are now synced"
        }
      }
      if {![::tools::testcs $netname $::irc::netname]} {
        puts "Received network name doesn't correspond to given network name in configuration. I have received $netname but I am waiting for $::irc::netname. Abort link."
        ::irc::send ":$::irc::servername [tok SQUIT] $::irc::hub :Configuration error."
        close $::irc::sock
        exit 0
      } else {
        ::tools::write_pid $::irc::pid
        set ::service 1
        # Call to hooks init
        if ([info exists ::irc::hook(init)]) {
          foreach hooki $::irc::hook(init) { if {$::debug} { puts "Hook init call : $hooki" }; $hooki }
        }
        ::tools::load_rights
        return
      }
    }
    "&" -
    NICK {
    #<<< NICK Yume       1        1326268587 chaton   192.168.42.1 1      0            +iowghaAxNz *           851AC590.11BF4B94.149A40B0.IP :Structure of Body
    #<<< NICK GameServer 1        1326702996 tclsh    tcl.hebeo.fr g      0            +oSqB       *           heb1-EAB106C8.hebeo.fr        :TCL GameServer Controller
    #    NICK nick       hopcount timestamp  username hostname     server servicestamp +usermodes  virtualhost cloakhost                     :realname
      set nickname [lindex $arg 1]
      #set hopcount [lindex $arg 2]
      #set timestamp [lindex $arg 3]
      #set ident [lindex $arg 4]
      #set realhost [lindex $arg 5]
      set numeric [lindex $arg 6]
      if {[string match *.* $numeric]} {
        set numericdec $::irc::srvname2num($numeric)
        if {$::debug} { puts "Connect of an user on a server without NS PROTOCTL : $numeric - $numericdec - $::irc::srvname2num($numericdec)" }
      } else {
        set numericdec [::tools::base2dec $numeric $::tools::ub64chars]
        if {$::debug} { puts "Connect of an user on a server with NS PROTOCTL : $numeric - $numericdec - $::irc::srvname2num($numericdec)" }
      }
      set numericname $::irc::srvname2num($numericdec)
      set servicestamp [lindex $arg 7]
      set umodes [lindex $arg 8]
      #set cloakhost [lindex $arg 9]
      #set vhost [lindex $arg 10]
      #set gecos [string range [lrange $arg 11 end] 1 end]
      lappend ::irc::userlist $nickname
      set ::irc::userlist [::tools::nodouble $::irc::userlist]
      lappend ::irc::users($numericname) $nickname
      set ::irc::users($numericname) [::tools::nodouble $::irc::users($numericname)]
      if {$::debug} { puts "Adding $nickname to server $numericname userlist : $::irc::users($numericname)" }
      if {$servicestamp != 0} { ::irc::reg_user add $nickname }
      ::irc::parse_umodes $nickname $umodes
      return
    }
    SQUIT {
    #<<< SQUIT irc2.hebeo.fr :Yume
    # TODO : remove srvname2num($numeric) corresponding to server
      set servername [lindex $arg 1]
      set numeric $::irc::srvname2num($servername)
      #set reason [string range [lrange $arg 2 end] 1 end]
      foreach user $::irc::users([string tolower $servername]) {
        ::irc::user_quit $user
      }
      if {[info exists ::irc::users($servername)]} { unset ::irc::users($servername) }
      array unset srvname2num $numeric
      array unset srvname2num $servername
      return
    }
  }
  # End of switch [lindex $arg 0]

###
###
###

  switch [lindex $arg 1] {
    "!" -
    PRIVMSG {
    # PRIVMSG
      set from [string range [lindex $arg 0] 1 end]
      set to [lindex $arg 2]
      set commc [list [string range [lindex $arg 3] 1 end] [lrange $arg 4 end]]
      set comm [::tools::stripmirc $commc]
      set text [::tools::stripmirc [lrange $arg 4 end]]
      # Hooks for global PRIVMSG
      if {$::debug} { puts "First char of \$to is [string index $to 0]"; puts "::irc::hook(privmsgchan) exist ? [info exists ::irc::hook(privmsgchan)]" }
      if {([string index $to 0]=="#") && ([info exists ::irc::hook(privmsgchan)])} { foreach hookp $::irc::hook(privmsgchan) { $hookp $from $to "$commc" } }
      # Hook for PRIVMSG to specific chan or user
      if {[info exists ::irc::hook(privmsg-[string tolower $to])]} { foreach hookp $::irc::hook(privmsg-[string tolower $to]) { $hookp $from "$commc" } }
      # COMMAND on Master Bot
      if {[::tools::test $to $::irc::nick]} {
        # Hook for COMMAND on Master Bot
        if {[info exists ::irc::hook(command-[string tolower [lindex $comm 0]])]} { foreach hookp $::irc::hook(command-[string tolower [lindex $comm 0]]) { $hookp $from "$commc" } }
        switch [lindex $comm 0] {
          root {
            if {[::tools::test [lindex $comm 1] "list"] && ![is_oper $from]} {
              ::irc::send ":$::irc::nick [tok NOTICE] $from :List of roots on $::irc::netname"
              foreach n $::irc::root {
                [is_reg $n] { set status "AUTHED" } { [is_user $n] { set status "NOT AUTHED" } { set status "NOT CONNECTED" } }
                ::irc::send ":$::irc::nick [tok NOTICE] $from :  $n   $status"
          } } }
          admin {
            set nick [lindex $comm 2]
            switch [lindex $comm 1] {
              add {
                if {![is_root $from]} { return }
                if {[::tools::is_root $nick]} { ::irc::send ":$::irc::nick [tok NOTICE] $from :$nick is on root list. Ha cannot be an admin."; return }
                if {[::tools::is_admin_only $nick]} { ::irc::send ":$::irc::nick [tok NOTICE] $from :$nick is already on admin list."; return }
                if {![is_reg $nick]} { ::irc::send ":$::irc::nick [tok NOTICE] $from :$nick is not authentified on nickserv."; return }
                # TODO : if nickserv module is loaded check if the nick is in db.
                lappend ::irc::rights(admin) $nick
                ::irc::send ":$::irc::nick [tok NOTICE] $from :$nick has been correctly added on admin list."
                ::tools::save_rights
              }
              del {
                if {![is_root $from]} { return }
                if {![::tools::is_admin_only $nick]} { ::irc::send ":$::irc::nick [tok NOTICE] $from :$nick is not on admin list."; return }
                set ::irc::rights(admin) [::tools::lremove $::irc::rights(admin) $nick]
                ::tools::save_rights
              }
              list {
                if {![is_oper $from]} { return }
                ::irc::send ":$::irc::nick [tok NOTICE] $from :List of admins on $::irc::netname"
                foreach n $::irc::admin {
                  [is_reg $n] { set status "AUTHED" } { [is_user $n] { set status "NOT AUTHED" } { set status "NOT CONNECTED" } }
                  ::irc::send ":$::irc::nick [tok NOTICE] $from :  $n   $status"
          } } } }
          oper {
            set nick [lindex $comm 2]
            switch [lindex $comm 1] {
              add {
                if {![is_admin $from]} { return }
                if {[::tools::is_root $nick]} { ::irc::send ":$::irc::nick [tok NOTICE] $from :$nick is on root list. Ha cannot be an admin."; return }
                if {[::tools::is_admin_only $nick]} { ::irc::send ":$::irc::nick [tok NOTICE] $from :$nick is already on admin list."; return }
                if {![is_reg $nick]} { ::irc::send ":$::irc::nick [tok NOTICE] $from :$nick is not authentified on nickserv."; return }
                # TODO : if nickserv module is loaded check if the nick is in db.
                lappend ::irc::admin $nick
                ::irc::send ":$::irc::nick [tok NOTICE] $from :$nick has been correctly added on admin list."
                ::tools::save_rights
              }
              del {
                if {![is_admin $from]} { return }
                if {![::tools::is_oper_only $nick]} { ::irc::send ":$::irc::nick [tok NOTICE] $from :$nick is not on oper list."; return }
                set ::irc::rights(oper) [::tools::lremove $::irc::rights(oper) $nick]
                ::tools::save_rights
              }
              list {
                if {![is_oper $from]} { return }
                ::irc::send ":$::irc::nick [tok NOTICE] $from :List of opers on $::irc::netname"
                foreach n $::irc::rights(oper) { ::irc::send ":$::irc::nick [tok NOTICE] $from :  $nick" }
          } } }
          version { return }
        }
      }
      # Some admins commands to manage the service
      if {[::tools::is_admin $from] && [::tools::test [string index [lindex $comm 0] 0] $::irc::cmdchar]} {
        switch [string range [lindex $comm 0] 1 end] {
          raw { set sraw [lrange [join $comm] 1 end]; ::irc::send $sraw; ::irc::send ":$::irc::nick PRIVMSG $::irc::adminchan :[::msgcat::mc cont_send $from $sraw]" }
          rehash { ::irc::rehash ; ::irc::send ":$::irc::nick [tok PRIVMSG] $::irc::adminchan :[::msgcat::mc cont_rehash $from]" }
          source {
            if {[file exists [lindex $comm 1]]} {
              if {[catch {source [lindex $comm 1]} error]} { puts "Error while loading [lindex $comm 1] : $error" }
              ::irc::send ":$::irc::nick [tok PRIVMSG] $::irc::adminchan :[::msgcat::mc cont_source $comm $from]"
            }
          }
          ssl {
            if {$::irc::ssl} {
              array set sslstatus [::tls::status $::irc::sock]
              ::irc::send ":$::irc::nick [tok PRIVMSG] $::irc::adminchan :SSL Status : Cipher       : $sslstatus(cipher)"
              ::irc::send ":$::irc::nick [tok PRIVMSG] $::irc::adminchan :SSL Status : Sbits        : $sslstatus(sbits)"
              ::irc::send ":$::irc::nick [tok PRIVMSG] $::irc::adminchan :SSL Status : Cert subject : $sslstatus(subject)"
              ::irc::send ":$::irc::nick [tok PRIVMSG] $::irc::adminchan :SSL Status : Cert issuer  : $sslstatus(issuer)"
              ::irc::send ":$::irc::nick [tok PRIVMSG] $::irc::adminchan :SSL Status : Cert hash    : $sslstatus(sha1_hash)"
              ::irc::send ":$::irc::nick [tok PRIVMSG] $::irc::adminchan :SSL Status : Cert begin   : $sslstatus(notBefore)"
              ::irc::send ":$::irc::nick [tok PRIVMSG] $::irc::adminchan :SSL Status : Cert end     : $sslstatus(notAfter)"
              ::irc::send ":$::irc::nick [tok PRIVMSG] $::irc::adminchan :SSL Status : Cert serial  : $sslstatus(serial)"
            } else {
              ::irc::send ":$::irc::nick [tok PRIVMSG] $::irc::adminchan :[::msgcat::mc cont_nossl]"
            }
          }
          tok { if {[catch {::irc::send ":$::irc::nick [tok PRIVMSG] $from :Token OK"} error]} { puts "Error token : $error" } }
          dcc {
            ::irc::send ":$::irc::nick [tok PRIVMSG] $from :\001DCC CHAT chat [::tools::intip $::pl::myip] $::pl::port\001"
            ::irc::send ":$::irc::nick [tok PRIVMSG] $::irc::adminchan :[::msgcat::mc cont_dcc $from]"
          }
          die { ::irc::shutdown $from $text }
        }
      }
      return
    }
    ES -
    EOS {
    # <<< :irc1.hebeo.fr ES
    # <<< :irc1.hebeo.fr EOS
      set server [string range [lindex $arg 0] 1 end]
      if {[::tools::test $server $::irc::hub]} {
        # Start timeout detection and cancel timer for reconnection loop
        ::irc::reset_timeout
        if {[info exists ::irc::connectout]} { catch { after cancel $::irc::connectout } }
        # Start my own ping to server
        ::tools::every 60 ::irc::pinghub
      }
    }
    9 -
    PONG {
      ::irc::reset_timeout
    }
    "&" -
    NICK {
    #<<< :Yume NICK Yuki 1326485191
      set oldnick [string range [lindex $arg 0] 1 end]
      set newnick [lindex $arg 2]
      #set timestamp [lindex $arg 3]
      set ::irc::userlist [::tools::llreplace $::irc::userlist $oldnick $newnick]
      if {[is_reg $oldnick]} { ::irc::reg_user del $oldnick; ::irc::reg_user add $newnick }
      foreach arr [array names ::irc::users *] { set ::irc::users($arr) [::tools::llreplace $::irc::users($arr) $oldnick $newnick] }
      # Hooks for nickchange
      if {[info exists ::irc::hook(nick)]} { foreach hookp $::irc::hook(nick) { $hookp $oldnick $newnick } }
      return
    }
    G -
    MODE {
    # :user MODE user +/-xxxx
      #set nick [lindex $arg 2]
      #set modes [lindex $arg 3]
      set source [lindex $arg 2]
      set target [lindex $arg 2]
      set modes [lindex $arg 3]
      [::tools::is_chan $target] { return } { ::irc::parse_umodes $nick $modes }
      return
    }
    "|" -
    UMODE2 {
    #<<< :Yume UMODE2 +oghaAN
    #<<< :Yume UMODE2 +owghaANqHp
      set nick [string range [lindex $arg 0] 1 end]
      set modes [lindex $arg 2]
      ::irc::parse_umodes $nick $modes
      return
    }
    n -
    v -
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
    "," -
    QUIT {
    #<<< :s220nov8kjwu9p9 QUIT :Client exited
    #<<< :Poker-egg QUIT :\[irc1.hebeo.fr\] Local kill by Yume (calin :D)
      set nickname [string range [lindex $arg 0] 1 end]
      set reason [string range [lrange $arg 2 end] 1 end]
      # Updating global variables
      ::irc::user_quit $nickname
      # Hooks for quit
      if {[info exists ::irc::hook(quit)]} { foreach hookj $::irc::hook(quit) { $hookj $nickname $reason } }
      return
    }
    "." -
    KILL {
    #<<< :Yume KILL Poker-egg :851AC590.11BF4B94.149A40B0.IP!Yume (salope)
    #<<< :irc1.hebeo.fr KILL UNO :irc1.hebeo.fr (Nick Collision)
      set killer [string range [lindex $arg 0] 1 end]
      set nickname [lindex $arg 2]
      #set path [string range [lindex $arg 3] 1 end]
      set reason [string range [lrange $arg 4 end] 1 end-1]
      # Updating global variables
      ::irc::user_quit $nickname
      # Hooks for kill
      if {[info exists ::irc::hook(kill)]} { foreach hookj $::irc::hook(kill) { $hookj $nickname $reason } }
      # reconnecting our bot
      if {[lindex $arg 2]==$::irc::nick} { bot_init $::irc::nick $::irc::username $::irc::hostname $::irc::realname }
      # Effectively killing our bots
      foreach n $::irc::botlist { if {[::tools::test $nickname $n]} { ::irc::send "[tok QUIT] $n :Kill by $killer : $reason" } }
      return
    }
    AA -
    SETHOST {
      # not in use
      return
    }
    AL -
    CHGHOST {
      # not in use
      return
    }
    AD -
    SETIDENT {
      # not in use
      return
    }
    AZ -
    CHGIDENT {
      # not in use
      return
    }
    AE -
    SETNAME {
      # not in use
      return
    }
    BK -
    CHGNAME {
      # not in use
      return
    }
    "#" -
    WHOIS {
    #<<< :Yume WHOIS Uno :uno
      set source [string range [lindex $arg 0] 1 end]
      set target [string range [lindex $arg 3] 1 end]
      if {[lsearch [string tolower $::irc::botlist] [string tolower $target]]<0} { return }
      ::irc::send ":$::irc::nick [tok PRIVMSG] $::irc::adminchan :[::msgcat::mc cont_whois0 $source $target]"
      ::irc::send ":$::irc::nick [tok NOTICE] $source :[::msgcat::mc cont_whois1 $target]"
      #::irc::send ":$target 320 whois is not implemented."
      #::irc::send ":$target 318 :End of /WHOIS list."
      return
    }
    BA -
    SWHOIS {
    #<<< @1 SWHOIS Yume :a trouve le passe de la oline magique
      # not in use
      return
    }
    "'" -
    SERVER {
    #<<< @1 SERVER irc2.hebeo.fr 2 2   :Hebeo irc1 server
    #<<< @1 SERVER irc2.hebeo.fr 2 131 :Hebeo irc2 server
    # Introducing distant server by hub
      #set srcnumeric [string range [lindex $arg 0] 1 end]
      set servername [lindex $arg 2]
      #set hopcount [lindex $arg 3]
      set numeric [lindex $arg 4]
      #set description [string range [lrange $arg 5 end] 1 end]
      set ::irc::srvname2num($numeric) $servername
      set ::irc::srvname2num($servername) $numeric
      set ::irc::users($servername) ""
      if {$::debug} { puts "Adding server numeric $numeric for server $servername." }
      return
    }
    AG -
    SDESC {
      # not in use
      return
    }
    2 -
    STATS {
      # not in use
      return
    }
    "~" -
    SJOIN {
    # During netsync
    #<<< :irc1.hebeo.fr SJOIN 1329117460 #Services +ntr :YumeNoYuki @~Hebeo @+*Yume
    #<<< :irc1.hebeo.fr SJOIN 1329117449 # :Yuki2 YumeNoYuki @Yume &yuki!*@* \"Yume!*@* \'yume!*@*
    #<<< :irc1.hebeo.fr SJOIN 1329117447 #opers +sntrO :Yuki2 YumeNoYuki @~Hebeo @*Yume 
    # After netsync
    #<<< @1 SJOIN 1325144112 #Poker :Yume 
    #<<< @1 SJOIN 1327468838 #UNO   :@Yume 
    # *owner ~protect @op %halfop +voice
    # &bans "banex 'invex
      #set numeric [string range [lindex $arg 0] 1 end]
      #set timestamp [lindex $arg 2]
      set chan [lindex $arg 3]
      set part0  [lindex [split [string range $arg 1 end] :] 0]
      set params [lindex [split [string range $arg 1 end] :] 1]
      set chmodes "[lindex $part0 4]"
      
      foreach p $params {
        regexp -all -- {([\&\"\']*)([*~@%+]*)([\w!*@~]+$)} $p "" chmodes chrights param
        set isnick true
        foreach chmode [::tools::charfilter $chmodes] {
          switch $chmode {
            &  {
              # bans
              set isnick false
            }
            \" {
              # ban exceptions
              set isnick false
            }
            \' {
              # invite exceptions
              set isnick false
            }
          }
        }
        # We parse chrights only if there is no chmodes
        if {$isnick} {
          foreach chright $chrights {
            switch $chright {
              * {
                #puts "$param is an owner"
              }
              ~ {
                #puts "$param is a protect"
              }
              @ {
                #puts "$param is an op"
              }
              % {
                #puts "$param is an halfop"
              }
              + {
                #puts "$param is a voice"
              }
            }
          }
          # Updating global variables
          ::irc::user_join $param $chan $chrights
        }
      }
    }
    C -
    JOIN {
    #<<< :Yume JOIN #blabla,#opers
      set nick [string range [lindex $arg 0] 1 end]
      set chans [join [split [lindex $arg 2] ,]]
      foreach chan [string tolower $chans] {
        # Updating global variables and calling hooks
        ::irc::user_join $nick $chan $chrights
      }
      return
    }
    D -
    PART {
    #<<< :Yume PART #Poker
    #<<< :Yume PART #test :bla bla ?
      set nick [string range [lindex $arg 0] 1 end]
      set chan [join [lindex $arg 2]]
      set reason "[string range [lindex $arg 3 end] 1 end]"
      # Updating global variables
      ::irc::user_part $nick $chan
      # Hooks for global part
      if {[info exists ::irc::hook(part)]} { foreach hookj $::irc::hook(part) { $hookj $nick $chan $reason } }
      # Hooks for specific part on a chan
      if {[info exists ::irc::hook(part-[string tolower $chan])]} { $::irc::hook(part-[string tolower $chan]) $nick $reason }
      return
    }
    H -
    KICK {
    # <<< :Yume KICK # Yuki2 :<3 je t\'aime
      set kicker [string range [lindex $arg 0] 1 end]
      set chan [lindex $arg 2]
      set nick [lindex $arg 3]
      set reason [string range [lrange $arg 4 end] 1 end]
      # Updating global variables
      ::irc::user_part $nick $chan
      # Hooks for global kick
      if {[info exists ::irc::hook(kick)]} { foreach hookj $::irc::hook(kick) { $hookj $kicker $chan $nick $reason } }
      # Hooks for specific kick on a chan
      if {[info exists ::irc::hook(kick-[string tolower $chan])]} { $::irc::hook(kick-[string tolower $chan]) $kicker $nick $reason }
      if {$nick==$::irc::nick} { join_chan $::irc::nick $chan }
      return
    }

  }
  # End of switch [lindex $arg 1]

  
}

# vim: set fenc=utf-8 sw=2 sts=2 ts=2 et filetype=tcl
