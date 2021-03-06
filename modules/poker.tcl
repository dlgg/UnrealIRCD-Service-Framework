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
# Product name : poker module for UnrealIRCD Service Framework
# Copyright (C) 2013 Damien Lesgourgues
# Author(s): Damien Lesgourgues
#
##############################################################################
puts [::msgcat::mc loadgame "Poker"]

namespace eval poker {
  namespace import ::tools::tok
  # Parametres pour le jeu Poker
  variable nick "Poker-FrameWork"
  variable username "poker"
  variable hostname "poker.$::irc::hostname"
  variable realname "Bot de jeu Poker"
  variable chan "#Poker"
  
  # Don't modify this
  ::irc::bot_init $::poker::nick $::poker::username $::poker::hostname $::poker::realname
  ::irc::join_chan $::poker::nick $::poker::chan
  ::irc::hook_register privmsg-[string tolower $::poker::chan] "::poker::control_pub"
  ::irc::hook_register privmsg-[string tolower $::poker::nick] "::poker::control_priv"
}

proc ::poker::control_pub { nick text } {
  if {[::tools::is_admin $nick]} { ::irc::send ":$::poker::nick [tok PRIVMSG] $::poker::chan :\002PUB \002 $nick > [join $text]" }
}

proc ::poker::control_priv { nick text } {
  if {[::tools::is_admin $nick]} { ::irc::send ":$::poker::nick [tok PRIVMSG] $::poker::chan :\002PRIV\002 $nick > [join $text]" }
}

# vim: set fenc=utf-8 sw=2 sts=2 ts=2 et filetype=tcl
