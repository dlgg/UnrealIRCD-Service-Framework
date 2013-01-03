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
# Product name : YouTube module for UnrealIRCD Service Framework
# Copyright (C) 2012 Damien Lesgourgues
# Author(s): Damien Lesgourgues
#
##############################################################################
puts [::msgcat::mc loadaddon "Dailymotion"]

package require Tcl 8.4
package require json

package require http
package require tls
http::register https 443 [list ::tls::socket -require 0]

namespace eval dailymotion {
# Register Master Bot Addon
  ::irc::hook_register privmsgchan "::dailymotion::control"

# Import useful procs
  namespace import ::tools::tok

# Vars for addon
  set logo "Dailymotion"
  set base "http://www.dailymotion.fr"
  set api "https://api.dailymotion.com/video/"
  set api_user "https://api.dailymotion.com/user/"
  set api_extra ""
  set agent "Mozilla/5.0 (Windows; U; Windows NT 5.1; ru; rv:1.9.0.1) Gecko/2008070208 Firefox/3.0.1"
  set timeout 30000
  set mode "full"
 
  proc control { nick chan text } {
    if {$::debug==1} { puts "Dailymotion : " }
    set textnc [::tools::stripmirc $text]
    set watch [regexp -nocase -- {\www\.dailymotion\.com/video/(.*)([0-9a-zA-Z])} $textnc "" dailymotionidd]
    if {$watch && $dailymotionidd != ""} {
      set dailymotionid "/video/$dailymotionidd"

      set link "$::dailymotion::api$dailymotionidd$::dailymotion::api_extra"
      if {$::debug==1} { puts "Dailymotion : Calling ::http::data with URI $link" }
      set t [::http::config -useragent $::dailymotion::agent]
      set t [::http::geturl $link -timeout $::dailymotion::timeout]
      set data [::http::data $t]
      ::http::cleanup $t
      set dailymotion_infos [::json::json2dict $data]

      set link "$::dailymotion::api_user[lindex $dailymotion_infos 1]"
      set t [::http::config -useragent $::dailymotion::agent]
      set t [::http::geturl $link -timeout $::dailymotion::timeout]
      set data [::http::data $t]
      ::http::cleanup $t
      set dailymotion_infos_user [::json::json2dict $data]

      ::irc::send ":$::irc::nick [tok PRIVMSG] $chan :$::dailymotion::logo - [lindex $dailymotion_infos 3] par [lindex $dailymotion_infos_user 3]"
    }
  }
}

# vim: set fenc=utf-8 sw=2 sts=2 ts=2 et filetype=tcl
