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
puts [::msgcat::mc loadgame "Poker"]

namespace eval poker {
  # Parametres pour le jeu Poker
  variable nick "Poker"
  variable username "poker"
  variable hostname "poker.$::mysock(hostname)"
  variable realname "Bot de jeu Poker"
  variable chan "#Poker"
  
  # Don't modify this
  if {[info exists ::mysock(gamelist2)]} { lappend ::mysock(gamelist2) "poker"; set ::mysock(gamelist2) [::nodouble $::mysock(gamelist2)] } else { set ::mysock(gamelist2) "poker" }
  if {![info exists ::network(users-[string tolower $poker::chan])]} { set ::network(users-[string tolower $poker::chan]) "" }
  set ::mysock(proc2-[string tolower $poker::chan]) "::poker::control_pub"
  set ::mysock(proc2-[string tolower $poker::nick]) "::poker::control_priv"
  
  proc control_pub { nick text } {
    fsend $::mysock(sock) ":$poker::nick PRIVMSG $poker::chan :\002PUB \002 $nick > [join $text]"
  }
  
  proc control_priv { nick text } {
    fsend $::mysock(sock) ":$poker::nick PRIVMSG $poker::chan :\002PRIV\002 $nick > [join $text]"
  }
}
