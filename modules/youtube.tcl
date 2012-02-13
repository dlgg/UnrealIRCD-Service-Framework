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
puts [::msgcat::mc loadaddon "YouTube"]

package require http
package require tls
http::register https 443 [list ::tls::socket -require 0]

namespace eval youtube {
# Register Master Bot Addon
  ::irc::hook_register privmsgchan "::youtube::control"

# Vars for addon
  set logo "\002\00301,00You\00300,04Tube\002\017"
  set base "http://www.youtube.com"
  set api "https://gdata.youtube.com/feeds/api/videos/"
  set agent "Mozilla/5.0 (Windows; U; Windows NT 5.1; ru; rv:1.9.0.1) Gecko/2008070208 Firefox/3.0.1"
  set timeout 30000
 
  proc control { nick chan text } {
    if {$::debug==1} { puts "YouTube : " }
    set textnc [::tools::stripmirc $text]
    set watch [regexp -nocase -- {\/watch\?v\=([^\s]{11})} $textnc "" youtubeidd]
    if {!$watch} { set watch [regexp -nocase -- {youtu\.be\/([^\s]{11})} $textnc "" youtubeidd] }
    if {!$watch} { set watch [regexp -nocase -- {v\=([^\s]{11})} $textnc "" youtubeidd] }
    if {$watch && $youtubeidd != ""} {
      set youtubeid "/watch?v=$youtubeidd"
      set link "$::youtube::api$youtubeidd?v=2"
      if {$::debug==1} { puts "YouTube : Calling ::http::data with URI $link" }
      ::irc::send ":$::irc::nick PRIVMSG $::irc::adminchan :$::youtube::logo \002$nick\002 on \002$chan\002 : $::youtube::base$youtubeid"
      set t [::http::config -useragent $::youtube::agent]
      set t [::http::geturl $link -timeout $::youtube::timeout]
      set data [::http::data $t]
      ::http::cleanup $t
      # reset des variables
      set title ""; set author ""; set favs 0; set view 0; set raters 0; set average 0; set comms 0; set dislike 0; set like 0; set duration 0
      regexp -all -- {<title>(.*?)</title>} $data "" title
      regexp -all -- {<name>(.*?)</name>} $data "" author
      regexp -all -- {favoriteCount='(.*?)'} $data "" favs
      regexp -all -- {viewCount='(.*?)'} $data "" view
      regexp -all -- {numRaters='(.*?)'} $data "" raters
      regexp -all -- {average='(.*?)'} $data "" average
      regexp -all -- {countHint='(.*?)'} $data "" comms
      regexp -all -- {numDislikes='(.*?)'} $data "" dislike
      regexp -all -- {numLikes='(.*?)'} $data "" like
      regexp -all -- {<yt:duration seconds='(.*?)'/>} $data "" duration
      if {$::debug==1} {
        puts "Title    : $title"
        puts "Author   : $author"
        puts "Duration : $duration seconds"
        puts "View     : $view"
        puts "Favs     : $favs"
        puts "Rate     : $average by $raters persons"
        puts "Comms    : $comms"
        puts "Likes    : $like"
        puts "Dislikes : $dislike"
      }
      ::irc::send ":$::irc::nick PRIVMSG [join [list $chan $::irc::adminchan] ,]  :$::youtube::logo \002$author\002 $title | \002Durée\002 :[::tools::duration $duration] | \002Vues\002 : $view | \002Favoris\002 : $favs"
      ::irc::send ":$::irc::nick PRIVMSG [join [list $chan $::irc::adminchan] ,]  :$::youtube::logo \002Note moyenne\002 : $average/5 \002par\002 $raters personnes | \002Commentaires\002 : $comms | \002J'aime\002 : $like | \002Je n'aime pas\002 : $dislike"
    }
  }
}

# vim: set fenc=utf-8 sw=2 sts=2 ts=2 et filetype=tcl
