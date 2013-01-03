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
puts [::msgcat::mc loadmodule "PartyLine"]

if {[info exists ::pl]} {
  if {$::debug==1} { puts [::msgcat::mc pl_alreadyload] }
} else {
  set ::pl 0
  set ::pl::socks ""
  set ::pl::authed ""
}

set ::pl::protcmd ".pass .close"

proc ::pl::server {} {
  if {[catch {socket -server ::pl::waiting -myaddr $::pl::ip $::pl::port} error]} { puts "Erreur lors de l'ouverture du socket ([set error])"; return 0 }
  puts [::msgcat::mc pl_openport]
  set ::pl 1
}

proc ::pl::waiting { sockpl addr dstport } {
  puts [::msgcat::mc pl_incconn]
  fileevent $sockpl readable [list ::pl::control $sockpl]
  fconfigure $sockpl -buffering line
  lappend ::pl::socks $sockpl
  set ::pl::socks [::tools::nodouble $::pl::socks]
  ::irc::send ":$::irc::nick PRIVMSG $::irc::adminchan :[::msgcat::mc pl_activated $sockpl $::pl::port $addr $dstport]"
  return
}

proc ::pl::closepl { socktoclose sockpl } {
  set ::pl::socks [::tools::lremove $::pl::socks $socktoclose]
  set ::pl::authed [::tools::lremove $::pl::authed $socktoclose]
  set msg [::msgcat::mc pl_close $socktoclose $sockpl]
  ::pl::send $socktoclose $msg
  ::irc::send ":$::irc::nick PRIVMSG $::irc::adminchan :\00304\002PL :\003\002 $msg"
  puts $msg
  close $socktoclose
  return
}

proc ::pl::control { sockpl } {
  set argv [gets $sockpl arg]
  set isauth 0
  foreach pl $::pl::authed { if {[::tools::test $pl $sockpl]} { set isauth 1 } }
  if {$argv=="-1"} {
    ::pl::closepl $sockpl "system"
  }
  set arg [::tools::charfilter $arg]
  if {$::debug==1} {
    set protected 0
    foreach protcmd $::pl::protcmd { if {[string tolower $protcmd]==[string tolower [lindex $arg 0]]} { set protected 1 } }
    if {$protected==0} {
      puts "<<< $sockpl <<< [join $arg]"
      foreach s $::pl::authed { if {![string equal $s $sockpl]} { puts $s "<<< $sock <<< [join $arg]" } }
      ::irc::send ":$::irc::nick PRIVMSG $::irc::adminchan :\00312PL <<<\002 $sockpl \002<<<\003 [join $arg]"
    }
  }
  
  if {$isauth==1} {
    switch [lindex $arg 0] {
      .help {
        ::pl::send $sockpl [::msgcat::mc pl_help0 $::irc::version]
        ::pl::send $sockpl " "
        ::pl::send $sockpl [::msgcat::mc pl_help1]
        ::pl::send $sockpl "------------------------------"
        ::pl::send $sockpl " "
        ::pl::send $sockpl ".who       [::msgcat::mc pl_help3]"
        ::pl::send $sockpl ".ssl       [::msgcat::mc pl_help6]"
        ::pl::send $sockpl ".close     [::msgcat::mc pl_help2]"
        ::pl::send $sockpl ".raw       [::msgcat::mc pl_help7]"
        ::pl::send $sockpl ".source    [::msgcat::mc pl_help8]"
        ::pl::send $sockpl ".rehash    [::msgcat::mc pl_help4]"
        ::pl::send $sockpl ".die       [::msgcat::mc pl_help5]"
        return
      }
      .close { [expr {"[lindex $arg 1]" == ""}] { ::pl::closepl $sockpl $sockpl } { ::pl::closepl [lindex $arg 1] $sockpl }; return }
      .who { ::pl::send $sockpl [::msgcat::mc pl_inpl $::pl::socks]; ::pl::send $sockpl [::msgcat::mc pl_inplauth $::pl::authed]; return }
      .ssl {
        if {$::irc::ssl} {
          array set sslstatus [::tls::status $::irc::sock]
          ::pl::send $sockpl "SSL Status : Cipher       : $sslstatus(cipher)"
          ::pl::send $sockpl "SSL Status : Sbits        : $sslstatus(sbits)"
          ::pl::send $sockpl "SSL Status : Cert subject : $sslstatus(subject)"
          ::pl::send $sockpl "SSL Status : Cert issuer  : $sslstatus(issuer)"
          ::pl::send $sockpl "SSL Status : Cert hash    : $sslstatus(sha1_hash)"
          ::pl::send $sockpl "SSL Status : Cert begin   : $sslstatus(notBefore)"
          ::pl::send $sockpl "SSL Status : Cert end     : $sslstatus(notAfter)"
          ::pl::send $sockpl "SSL Status : Cert serial  : $sslstatus(serial)"
        } else {
          ::pl::send $sockpl "[::msgcat::mc cont_nossl]"
        }
      }
      .source {
        if {[file exists [lindex $arg 1]]} {
          if {[catch {source [lindex $arg 1]} error]} { puts "Error while loading [lindex $arg 1] : $error" }
          ::irc::send ":$::irc::nick [tok PRIVMSG] $::irc::adminchan :[::msgcat::mc cont_source [lindex $arg 1] $sockpl]"
        }
      }
      .raw { set sraw [lrange [join $arg] 1 end]; ::irc::send $sraw; ::irc::send ":$::irc::nick PRIVMSG $::irc::adminchan :[::msgcat::mc cont_send $sockpl $sraw]" }
      .rehash { ::irc::rehash ; ::irc::send ":$::irc::nick PRIVMSG $::irc::adminchan :\00304\002PL :\003\002 [::msgcat::mc cont_rehash $sockpl]"; return }
      .die { ::irc::send ":$::irc::nick PRIVMSG $::irc::adminchan :\00304\002PL :\003\002 [::msgcat::mc pl_die $sockpl]"; ::irc::shutdown $sockpl; return }
    }
  } else {
    if {([lindex $arg 0]==".pass")} {
      if {[string equal [lindex $arg 1] $::pl::pass]} {
        ::pl::send $sockpl [::msgcat::mc pl_auth0]
        ::irc::send ":$::irc::nick PRIVMSG $::irc::adminchan :[::msgcat::mc pl_auth1 $sockpl]"
        foreach s $::pl::authed { ::pl::send $s ">>> $sockpl >>> [::msgcat::mc pl_auth1 $sockpl]" }
        lappend ::pl::authed $sockpl
        set ::pl::authed [::tools::nodouble $::pl::authed]
        return
      } else {
        ::pl::send $sockpl [::msgcat::mc pl_notauth]
        ::irc::send ":$::irc::nick PRIVMSG $::irc::adminchan :[::msgcat::mc pl_auth2 $sockpl]"
        foreach s $::pl::authed { ::pl::send $s ">>> $sockpl >>> [::msgcat::mc pl_auth2 $sockpl]" }
        return
      }
    } elseif {[lindex $arg 0]==".close"} {
      if {[lindex $arg 1]==""} {
        ::pl::closepl $sockpl $sockpl
        return
      } else {
        ::pl::closepl [lindex $arg 1] $sockpl
        return
      } 
    } else {
      ::pl::send $sockpl [::msgcat::mc pl_notauth]
      return
    }
  }
}

puts [::msgcat::mc pl_loaded]
if {$::pl==0} { puts [::msgcat::mc pl_activation $::pl::ip $::pl::port]; ::pl::server }

# vim: set fenc=utf-8 sw=2 sts=2 ts=2 et filetype=tcl
