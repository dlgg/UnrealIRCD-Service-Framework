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
puts [::msgcat::mc loadlimit "Limit"]

namespace eval limit {
# Register Master Bot Addon
  ::irc::hook_register privmsgchan "::limit::control"

# Vars for limit
  set chans "#UNO #1000Bornes #Poker"
  set limit 5
}

proc ::limit::control { nick chan text } {
  # Body goes here
}

# vim: set fenc=utf-8 sw=2 sts=2 ts=2 et filetype=tcl
