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
puts [::msgcat::mc loadaddon "Loggger"]

namespace eval logger {
# Register Master Bot Addon
  ::irc::hook_register privmsgchan "::logger::log_privmsg"

# Vars for addon  
}

proc ::logger::log_privmsg { nick chan text } {
  if {![file isdirectory "files/logs"]} {
    file mkdir "files/logs"
  }

  set textnc [::tools::stripmirc $text]
  regsub -all {[\000-\010]|[\013-\037]|[\177]} $textnc {} textnc
  
  set file "files/logs/$chan.log"
  
  set fp [open $file "a"]
  
  puts $fp "[clock format [clock seconds] -format %H:%M:%S] < $nick > $textnc"
  
  close $fp
}

# vim: set fenc=utf-8 sw=2 sts=2 ts=2 et filetype=tcl
