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
# Copyright (C) 2013 Damien Lesgourgues
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
  ::irc::hook_register command-limit "::limit::command"

# Vars for limit
  variable chandb "files/limit.chans"
  variable limit 5
  variable refresh 15
  variable log 1

### Don't modify below this
  variable currl
# Importing tok proc
  namespace import ::tools::tok
}

proc ::limit::control { nick chan text } {
  # Body goes here
  return
}

proc ::limit::part { nick chan reason } {
  set chan [string tolower $chan]
  if {$::debug} { puts "There is now [llength $::irc::users($chan)] users on channel $chan : $::irc::users($chan)" }
  foreach c [string tolower $::limit::chans] { if {[::tools::test $chan $c]} { setlimit $chan } }
  return
}
proc ::limit::kick { kicker chan nick reason } { ::limit::part $nick $chan $reason; return }

proc ::limit::init {} {
  if {$::service=="0"} { return }
  foreach chan [string tolower $::limit::chans] {
    if {![info exist ::irc::users($chan)]} { ::irc::join_chan $::irc::nick $chan }
    if {[lsearch -exact -nocase $::irc::users($chan) $::irc::nick] < 0} { ::irc::join_chan $::irc::nick $chan }
    setlimit $chan
  }
  return
}

proc ::limit::setlimit { chan } {
  set limitset [expr {[llength $::irc::users($chan)] + $::limit::limit }]
  if { $limitset != $::limit::currl($chan) } {
    forcelimit $chan
  }
  return
}
proc ::limit::forcelimit { chan } {
  if {![info exist ::irc::users($chan)]} { ::irc::join_chan $::irc::nick $chan }
  if {[lsearch -exact -nocase $::irc::users($chan) $::irc::nick] < 0} { ::irc::join_chan $::irc::nick $chan }
  set limitset [expr {[llength $::irc::users($chan)] + $::limit::limit }]
  if {$::debug} { puts "Setting limit of $chan to $limitset" }
  ::irc::send ":$::irc::nick [tok MODE] $chan +l $limitset"
  set ::limit::currl($chan) $limitset
  return
}

proc ::limit::command { nick args } {
  set args [join [join $args]]
  if {$::debug} { puts "LIMIT : command used by $nick : [lindex $args 1] : [lrange $args 2 end]" }
  switch [lindex $args 1] {
    help {
      if {$::limit::log} { ::irc::send ":$::irc::nick [tok PRIVMSG] $::irc::adminchan :\002LIMIT\002 $nick : help" }
      ::limit::print_help $nick
      return
    }
    add {
      set chan [string tolower [lindex $args 2]]
      if {![::irc::is_chan $chan]} { ::irc::send ":$::irc::nick [tok NOTICE] $nick :You need to provide a chan in parameters."; return }
      if {![::irc::is_admin $nick]} { ::irc::send ":$::irc::nick [tok NOTICE] $nick :You are not admin."; return }
      if {[lsearch -exact -nocase $::limit::chans $chan] >= 0} { ::irc::send ":$::irc::nick [tok NOTICE] $nick :limit module is already activate on $chan."; return }
      set ::limit::currl($chan) 0
      lappend ::limit::chans $chan
      forcelimit $chan
      saveDB
      ::irc::send ":$::irc::nick [tok NOTICE] $nick :limit module has been correctly activated on $chan."
      if {$::limit::log} { ::irc::send ":$::irc::nick [tok PRIVMSG] $::irc::adminchan :\002LIMIT\002 $nick : add $chan" }
      return
    }
    del {
      set chan [string tolower [lindex $args 2]]
      if {![::irc::is_chan $chan]} { ::irc::send ":$::irc::nick [tok NOTICE] $nick :You need to provide a chan in parameters."; return }
      if {![::irc::is_admin $nick]} { ::irc::send ":$::irc::nick [tok NOTICE] $nick :You are not admin."; return }
      if {[lsearch -exact -nocase $::limit::chans $chan] == -1} { ::irc::send ":$::irc::nick [tok NOTICE] $nick :limit module is not activate on $chan."; return }
      set ::limit::chans [::tools::lremove $::limit::chans $chan]
      array unset ::limit::currl $chan
      ::irc::send ":$::irc::nick [tok MODE] $chan -l"
      saveDB
      ::irc::send ":$::irc::nick [tok NOTICE] $nick :limit module has been correctly desactivated on $chan."
      if {$::limit::log} { ::irc::send ":$::irc::nick [tok PRIVMSG] $::irc::adminchan :\002LIMIT\002 $nick : del $chan" }
      return
    }
    show {
      if {![::irc::is_admin $nick]} { ::irc::send ":$::irc::nick [tok NOTICE] $nick :You are not admin."; return }
      ::irc::send ":$::irc::nick [tok NOTICE] $nick :This is the list of chans where limit module is active :"
      # TODO : make list sent by group of 10
      ::irc::send ":$::irc::nick [tok NOTICE] $nick :[join $::limit::chans]"
      if {$::limit::log} { ::irc::send ":$::irc::nick [tok PRIVMSG] $::irc::adminchan :\002LIMIT\002 $nick : show" }
      return
    }
    force {
      set chan [string tolower [lindex $args 2]]
      if {![::irc::is_chan $chan]} { ::irc::send ":$::irc::nick [tok NOTICE] $nick :You need to provide a chan in parameters."; return }
      if {![::irc::is_admin $nick]} { ::irc::send ":$::irc::nick [tok NOTICE] $nick :You are not admin."; return }
      if {[lsearch -exact -nocase $::limit::chans $chan] == -1} { ::irc::send ":$::irc::nick [tok NOTICE] $nick :limit module is not activated on $chan. Please activate it before."; return }
      forcelimit $chan
      if {$::limit::log} { ::irc::send ":$::irc::nick [tok PRIVMSG] $::irc::adminchan :\002LIMIT\002 $nick : force $chan" }
      return
    }
    default {
      ::limit::print_help $nick
      return
    }
  }
  return
}

proc ::limit::print_help { nick } {
  ::irc::send ":$::irc::nick [tok NOTICE] $nick :\002Limit module help"
  ::irc::send ":$::irc::nick [tok NOTICE] $nick : "
  ::irc::send ":$::irc::nick [tok NOTICE] $nick :\002help\002         : Print help"
  ::irc::send ":$::irc::nick [tok NOTICE] $nick :\002add\002 <chan>   : Active limit protection on <chan>"
  ::irc::send ":$::irc::nick [tok NOTICE] $nick :\002del\002 <chan>   : Unactive limit protection on <chan>"
  ::irc::send ":$::irc::nick [tok NOTICE] $nick :\002show\002         : Show the list of chans where limit protection is active"
  ::irc::send ":$::irc::nick [tok NOTICE] $nick :\002force\002 <chan> : Force reset of limit on <chan>"
  return
}

proc ::limit::loadDB {} {
  if {![file writable $::limit::chandb]} { if {[file exists $::limit::chandb} { puts "$::limit::chandb is not writable. Please correct this."; exit } else { set f [open $::limit::chandb w]; close $f } }
  set f [open $::limit::chandb r]
  set content [read -nonewline $f]
  close $f
  if {[info exists ::limit::chans]} { unset ::limit::chans }
  foreach line [split $content "\n"] { lappend ::limit::chans [string tolower $line] }
  set ::limit::chans [::tools::nodouble $::limit::chans]
  return
}

proc ::limit::saveDB {} {
  set f [open $::limit::chandb w]
  foreach c $::limit::chans { puts $f $c }
  close $f
  return
}

# initialize current limit array
::limit::loadDB
foreach c [string tolower $::limit::chans] { if {![info exists ::limit::currl($c)]} { set ::limit::currl($c) 0 } }

if {$::debug} { puts "Starting limit timer : ::tools::every $::limit::refresh ::limit::init" }
::tools::every $::limit::refresh ::limit::init

# vim: set fenc=utf-8 sw=2 sts=2 ts=2 et filetype=tcl
