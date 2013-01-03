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
# Product name : AddonName module for UnrealIRCD Service Framework
# Copyright (C) 2013 Damien Lesgourgues
# Author(s): COUTURIER-GUILLAUME Eric
#
##############################################################################
# TODO
#
# - Timer for show the current song
##############################################################################

puts [::msgcat::mc loadaddon "ShoutCast"]

namespace eval shoutcast {
# Register Master Bot Addon
  ::irc::hook_register privmsgchan "::shoutcast::control"

# Vars for addon
  variable cmdchar $::irc::cmdchar

  variable host $::irc::shoutcast_host
  variable port $::irc::shoutcast_port
}

proc ::shoutcast::control { nick chan text } {
  set textnc [::tools::stripmirc $text]

  if {[::tools::test [string index [lindex $textnc 0] 0] $::fantasy::cmdchar]} {
    set cmd [string range [lindex $textnc 0] 1 end]
    set paramsnc [join [lrange $textnc 1 end]]

    switch $cmd {
      radio {
        set sock [socket $::shoutcast::host $::shoutcast::port]
        puts $sock "GET /7.html HTTP/1.0"
        puts $sock "User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:0.9.9)"
        puts $sock "Host: $::shoutcast::host"
        puts $sock "Connection: close"
        puts $sock ""
        flush $sock

        while {[eof $sock] != 1} {
          regexp -all {<body>(.+)</body>} [gets $sock] x match
          if {[info exists match]} {
            set get [split $match ',']
            ::irc::send ":$::irc::nick ! $chan :Titre en cours de lecture : [lindex $get 6]"
          }
        }
        close $sock
      }
      auditeurs {
        set sock [socket $::shoutcast::host $::shoutcast::port]
        puts $sock "GET /7.html HTTP/1.0"
        puts $sock "User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:0.9.9)"
        puts $sock "Host: $::shoutcast::host"
        puts $sock "Connection: close"
        puts $sock ""
        flush $sock

        while {[eof $sock] != 1} {
          regexp -all {<body>(.+)</body>} [gets $sock] x match
          if {[info exists match]} {
            set get [split $match ',']
            ::irc::send ":$::irc::nick ! $chan :Actuellement [lindex $get 0] auditeur[::tools::pluralize [lindex $get 0]]"
          }
        }
        close $sock
      }
    }
  }  
}
