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
# TODO
#  - base fantasy command of controller needs to work only where Master Bot is
#  - parser for SJOIN
#
##############################################################################

# Load internal needed scripts
source config.tcl
source tools.tcl
source controller.tcl
source pl.tcl

# Load modules
puts "List of modules to load : $::irc::modules"
foreach file $::irc::modules {
  append file ".tcl"
  set file modules/$file
  if {$debug==1} { puts "Checking if exist : $file" }
  if {[file exists $file]} {
    if {$debug==1} { puts "Trying to load : $file" }
    if {[catch {source $file} err]} { puts "Error loading $file \n$::errorInfo"; exit }
  } else {
    if {$debug==1} { puts "File not exists : $file" }
    puts [::msgcat::mc filenotexist $file]
  }
}

if {$service=="0"} { puts [::msgcat::mc cont_netconn]; ::irc::socket_connect }

# vim: set fenc=utf-8 sw=2 sts=2 ts=2 et filetype=tcl
