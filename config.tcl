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
# Product name :  TCL GameServer
# Copyright (C) 2011 Damien Lesgourgues
# Author(s): Damien Lesgourgues
#
##############################################################################
# packages needed
package require msgcat

# Debug ... or not ?
set mysock(debug) 1

# Chargement des fichiers de langue
foreach file [glob -directory lang/ *.msg] {
  if {$mysock(debug)==1} { puts [::msgcat::mc loading $file] }
  source $file
}

# Setting default lang
set mysock(lang) "fr"
proc set_lang {lang} { if {$lang != ""} { ::msgcat::mclocale $lang } }
set_lang $mysock(lang)

# Logging message
puts [::msgcat::mc loadmodule "Configuration"]

# System configuration
set mysock(pid) framework.pid

# Service configuration
set mysock(ip) 192.168.42.4
set mysock(port) 7000
set mysock(password) "tclpur"
set mysock(numeric) 51
set mysock(servername) "tcl2.hebeo.fr"
set mysock(networkname) "Hebeo"
set mysock(hub) "irc1.hebeo.fr"

# Master Bot controller
set mysock(nick) FrameWork
set mysock(username) tclsh
set mysock(hostname) "tcl2.hebeo.fr"
set mysock(realname) "TCL GameServer Controller"
set mysock(adminchan) "#Services"
set mysock(chanlist) "#opers #blabla"
set mysock(root) "Yume"
set mysock(cmdchar) "."

# Partyline configuration
set mysock(plip) 0.0.0.0
set mysock(plport) 46000
set mysock(plpass) "password"

# Games/Addons
set mysock(toload) ""

# Internal variables
set mysock(version) "0.1"
set mysock(proc-addon) ""
set service 0
if {[info exists pl]} {
  if {$mysock(debug)==1} { puts [::msgcat::mc pl_alreadyload] }
} else {
  set pl 0
  set mysock(pl) ""
  set mysock(plauthed) ""
}
set network(servername-$mysock(numeric)) $mysock(servername)
set mysock(mychans) "$mysock(adminchan) $mysock(chanlist)" 

# Variables for network
if {![info exists network(users-[string tolower $mysock(adminchan)])]} { set network(users-[string tolower $mysock(adminchan)]) "" }
foreach chan [string tolower $mysock(chanlist)] { if {![info exists network(users-$chan)]} { set network(users-$chan) "" } }
if {![info exists network(userlist)]} { set network(userlist) "" }
if {![info exists network(chanlist)]} { set network(chanlist) "" }

