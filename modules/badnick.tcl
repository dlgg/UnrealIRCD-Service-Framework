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
# Product name : Badnick module for UnrealIRCD Service Framework
# Copyright (C) 2012 Damien Lesgourgues
# Author(s): Damien Lesgourgues
#
##############################################################################
puts [::msgcat::mc loadaddon "Badnick"]

namespace eval badnick {
# Register Master Bot Addon
  ::irc::hook_register join "::badnick::join"
  ::irc::hook_register nick "::badnick::nick"
  ::irc::hook_register command-badnick "::badnick::command"

# Vars for badnick
  variable chandb "files/badnick.chans"
  variable listdb "files/badnick.list"
  variable kickreason ""
  # ban time in seconds : 3600 = 1 hours / 0 for no auto unban
  variable bantime 3600
  variable log 1

### Don't modify below this
# Importing tok proc
  namespace import ::tools::tok
}

proc ::badnick::join { nick chan } {
  set chan [string tolower $chan]
  if {[lsearch -exact -nocase $::badnick::chans $chan] == -1} { return }
  foreach bad $::badnick::list {
    if {[string match -nocase $bad $nick]} {
      ::irc::send ":$::irc::nick [tok KICK] $chan $nick :$::badnick::kickreason"
      set mask $bad
      append mask "!*@*"
      ::irc::send ":$::irc::nick [tok MODE] $chan +b $mask"
      if {$::badnick::log} { ::irc::send ":$::irc::nick PRIVMSG $::irc::adminchan :\002BADNICK\002 ban of $nick ($mask) on $chan" }
      if {$bantime != 0} { after [expr {$::badnick::bantime * 1000}] {::badnick::unban $chan $mask} }
      return
    }
  }
  return
}

proc ::badnick::nick { oldnick nick } {
  foreach arr [array names ::irc::users *] { if {[::irc::is_chan $arr]} { if {[lsearch -exact -nocase $::irc::users($arr) $nick] >= 0} { ::badnick::join $nick $arr } } }
  return
}

proc ::badnick::unban { chan mask } {
  if {$::badnick::log} { ::irc::send ":$::irc::nick PRIVMSG $::irc::adminchan :\002BADNICK\002 auto unban of $mask on $chan" }
  ::irc::send "$::irc::nick [tok MODE] $chan -b $mask"
  return
}

proc ::badnick::command { nick args } {
  set args [join [join $args]]
  if {$::debug} { puts "BADNICK : command used by $nick : [lindex $args 1] : [lrange $args 2 end]" }
  switch [lindex $args 1] {
    help {
      if {$::badnick::log} { ::irc::send ":$::irc::nick [tok PRIVMSG] $::irc::adminchan :\002BADNICK\002 $nick : help" }
      ::badnick::print_help $nick
      return
    }
    addchan {
      set chan [string tolower [lindex $args 2]]
      if {$::badnick::log} { ::irc::send ":$::irc::nick [tok PRIVMSG] $::irc::adminchan :\002BADNICK\002 $nick : add $chan" }
      if {![::irc::is_chan $chan]} { ::irc::send ":$::irc::nick [tok NOTICE] $nick :You need to provide a chan in parameters."; return }
      if {![::irc::is_admin $nick]} { ::irc::send ":$::irc::nick [tok NOTICE] $nick :You are not admin."; return }
      if {[lsearch -exact -nocase $::badnick::chans $chan] >= 0} { ::irc::send ":$::irc::nick [tok NOTICE] $nick :badnick module is already activate on $chan."; return }
      lappend ::badnick::chans $chan
      saveDB
      ::irc::send ":$::irc::nick [tok NOTICE] $nick :badnick module has been correctly activated on $chan."
      return
    }
    delchan {
      set chan [string tolower [lindex $args 2]]
      if {$::badnick::log} { ::irc::send ":$::irc::nick [tok PRIVMSG] $::irc::adminchan :\002BADNICK\002 $nick : del $chan" }
      if {![::irc::is_chan $chan]} { ::irc::send ":$::irc::nick [tok NOTICE] $nick :You need to provide a chan in parameters."; return }
      if {![::irc::is_admin $nick]} { ::irc::send ":$::irc::nick [tok NOTICE] $nick :You are not admin."; return }
      if {[lsearch -exact -nocase $::badnick::chans $chan] == -1} { ::irc::send ":$::irc::nick [tok NOTICE] $nick :badnick module is not activate on $chan."; return }
      set ::badnick::chans [::tools::lremove $::badnick::chans $chan]
      saveDB
      ::irc::send ":$::irc::nick [tok NOTICE] $nick :badnick module has been correctly desactivated on $chan."
      return
    }
    addmask {
      # TODO
      return
    }
    delmask {
      # TODO
      return
    }
    show {
      if {$::badnick::log} { ::irc::send ":$::irc::nick [tok PRIVMSG] $::irc::adminchan :\002BADNICK\002 $nick : show" }
      if {![::irc::is_admin $nick]} { ::irc::send ":$::irc::nick [tok NOTICE] $nick :You are not admin."; return }
      ::irc::send ":$::irc::nick [tok NOTICE] $nick :This is the list of chans where badnick module is active :"
      # TODO : make list sent by group of 10
      ::irc::send ":$::irc::nick [tok NOTICE] $nick :[join $::badnick::chans]"
      return
    }
    reload {
      if {![::irc::is_admin $nick]} { ::irc::send ":$::irc::nick [tok NOTICE] $nick :You are not admin."; return }
      if {$::badnick::log} { ::irc::send ":$::irc::nick [tok PRIVMSG] $::irc::adminchan :\002BADNICK\002 $nick : reload" }
      ::badnick::loadDB
      ::irc::send ":$::irc::nick [tok NOTICE] $nick :List of bad nicks patterns reloaded"
      return
    }
    default {
      ::badnick::print_help $nick
      return
    }
  }
  return
}

proc ::badnick::print_help { nick } {
  ::irc::send ":$::irc::nick [tok NOTICE] $nick :\002Badnick module help"
  ::irc::send ":$::irc::nick [tok NOTICE] $nick : "
  ::irc::send ":$::irc::nick [tok NOTICE] $nick :\002help\002            : Print help"
  ::irc::send ":$::irc::nick [tok NOTICE] $nick :\002addchan\002 <chan>  : Active badnick protection on <chan>"
  ::irc::send ":$::irc::nick [tok NOTICE] $nick :\002delchan\002 <chan>  : Unactive badnick protection on <chan>"
  ::irc::send ":$::irc::nick [tok NOTICE] $nick :\002addmask\002 <mask>  : add <mask> to the list of detected mask \002UNACTIVE FOR THE MOMENT"
  ::irc::send ":$::irc::nick [tok NOTICE] $nick :\002delmask\002 <mask>  : del <mask> to the list of detected mask \002UNACTIVE FOR THE MOMENT"
  ::irc::send ":$::irc::nick [tok NOTICE] $nick :\002show\002            : Show the list of chans where badnick protection is active"
  ::irc::send ":$::irc::nick [tok NOTICE] $nick :\002reload\002          : Reload the list of bad nicks"
  return
}

proc ::badnick::loadDB {} {
# load chans DB
  set f [open $::badnick::chandb r]
  set content [read -nonewline $f]
  close $f
  if {[info exists ::badnick::chans]} { unset $::badnick::chans }
  foreach line [split $content "\n"] { lappend ::badnick::chans [string tolower $line] }
  set ::badnick::chans [::tools::nodouble $::badnick::chans]
# load bad nick DB
  set f [open $::badnick::listdb r]
  set content [read -nonewline $f]
  close $f
  if {[info exists ::badnick::list]} { unset $::badnick::list }
  foreach line [split $content "\n"] { lappend ::badnick::list [string tolower $line] }
  set ::badnick::list [::tools::nodouble $::badnick::list]
  return
}

proc ::badnick::saveDB {} {
  set f [open $::badnick::chandb w]
  foreach c $::badnick::chans { puts $f $c }
  close $f
  set f [open $::badnick::listdb w]
  foreach c $::badnick::list { puts $f $c }
  close $f
  return
}

# initialize current badnick array
::badnick::loadDB

# vim: set fenc=utf-8 sw=2 sts=2 ts=2 et filetype=tcl
