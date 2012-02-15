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
# Product name : Limit module for UnrealIRCD Service Framework
# Copyright (C) 2012 Damien Lesgourgues
# Author(s): Damien Lesgourgues
#
##############################################################################
puts [::msgcat::mc loadaddon "Limit"]

namespace eval limit {
# Register Master Bot Addon
  #::irc::hook_register privmsgchan "::limit::control"
  ::irc::hook_register part "::limit::part"
  ::irc::hook_register kick "::limit::kick"
  ::irc::hook_register init "::limit::init"

# Vars for limit
  variable chans "#UNO #1000Bornes #Poker #"
  variable limit 5
  variable refresh 15

### Don't modify below this
  variable ::limit::currl
# Importing tok proc
  namespace import ::tools::tok
}

proc ::limit::control { nick chan text } {
  # Body goes here
}

proc ::limit::part { nick chan reason } {
  set chan [string tolower $chan]
  if {$::debug} { puts "There is now [llength $::irc::users($chan)] users on channel $chan : $::irc::users($chan)" }
  foreach c [string tolower $::limit::chans] { if {[::tools::test $chan $c]} { setlimit $chan } }
}
proc ::limit::kick { kicker chan nick reason { ::limit::part $nick $chan $reason }

proc ::limit::init {} {
  if {$::service=="0"} { return }
  foreach chan [string tolower $::limit::chans] { setlimit $chan }
}

proc ::limit::setlimit { chan } {
  set limitset [expr {[llength $::irc::users($chan)] + $::limit::limit }]
  if { $limitset != $::limit::currl($chan) } {
    if {$::debug} { puts "Setting limit of $chan to $limitset" }
    ::irc::send ":$::irc::nick [tok MODE] $chan +l $limitset"
    set ::limit::currl($chan) $limitset
  }
}

# initialize current limit array
foreach c [string tolower $::limit::chans] { if {![info exists ::limit::currl($c)]} { set ::limit::currl($c) 0 } }

if {$::debug} { puts "Starting limit timer : ::tools::every $::limit::refresh ::limit::init" }
::tools::every $::limit::refresh ::limit::init

# vim: set fenc=utf-8 sw=2 sts=2 ts=2 et filetype=tcl
