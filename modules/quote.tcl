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
# Product name : AddonName module for UnrealIRCD Service Framework
# Copyright (C) 2012 Damien Lesgourgues
# Author(s): Damien Lesgourgues
#
##############################################################################
puts [::msgcat::mc loadaddon "Quote"]

namespace eval quote {
# Register Master Bot Addon
  ::irc::hook_register privmsgchan "::quote::control"

# Vars for addon
  variable quotefile "files/quotes.db"
  namespace import ::tools::tok
}

proc ::quote::control { nick chan text } {
  set textnc [::tools::stripmirc $text]

  if {[::tools::test [string index [lindex $textnc 0] 0] $::fantasy::cmdchar]} {
    set cmd [string range [lindex $textnc 0] 1 end]
    set paramsnc [join [lrange $textnc 1 end]]
    
    switch $cmd {
	quote {
	  set fd [open $::quote::quotefile "r"]
	  set data [read $fd]
	  close $fd
	  set data [split $data \n]
	  ::irc::send ":$::irc::nick [tok PRIVMSG] $chan :[lindex $data [::tools::rand 0 [llength $data]]]"
	}
	
	add_quote {
	  
	}
    }
  }
}

# vim: set fenc=utf-8 sw=2 sts=2 ts=2 et filetype=tcl
