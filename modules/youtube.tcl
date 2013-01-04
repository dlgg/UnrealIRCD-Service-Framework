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
# Copyright (C) 2013 Damien Lesgourgues
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
  ::irc::hook_register command-youtube "::youtube::command"

# Import useful procs
  namespace import ::tools::tok

# Vars for addon
  set logo "\002\00301,00You\00300,04Tube\002\017"
  set dbfile "files/youtube.db"
  set base "http://www.youtube.com"
  set api "https://gdata.youtube.com/feeds/api/videos/"
  set agent "Mozilla/5.0 (Windows; U; Windows NT 5.1; ru; rv:1.9.0.1) Gecko/2008070208 Firefox/3.0.1"
  set timeout 30000
  # If log is 1 then the output will be displayed on $::irc::admin chan too.
  set log 1
  set mode "light"
  var db
 
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
      ::irc::send ":$::irc::nick [tok PRIVMSG] $::irc::adminchan :$::youtube::logo \002$nick\002 on \002$chan\002 : $::youtube::base$youtubeid"
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
      if {$::youtube::log} { set outdest [join [list $chan $::irc::admin] ,] } else { set outdest $chan }
      switch $::youtube::db($chan) {
        full { set outmode full }
        light { set outmode light }
        none { set outmode none }
        default { set outmode $::youtube::mode }
      }
      switch $outmode {
        full {
          ::irc::send ":$::irc::nick [tok PRIVMSG] $outdest :$::youtube::logo \002$author\002 : $title | \002Dur?e\002 :[::tools::duration $duration] | \002Vues\002 : $view | \002Favoris\002 : $favs"
          ::irc::send ":$::irc::nick [tok PRIVMSG] $outdest :$::youtube::logo \002Note moyenne\002 : $average/5 \002par\002 $raters personnes | \002Commentaires\002 : $comms | \002J'aime\002 : $like | \002Je n'aime pas\002 : $dislike"
        }
        light { ::irc::send ":$::irc::nick [tok PRIVMSG] $outdest :$::youtube::logo \002$author\002 : $title | \002Dur?e\002 :[::tools::duration $duration] | \002Vues\002 : $view | \002Favoris\002 : $favs | \002Note moyenne\002 : $average/5 \002par\002 $raters personnes" }
        none { return }
        default { ::irc::send ":$::irc::nick [tok PRIVMSG] $::irc::admin :$::youtube::logo Bad mode for output : $::youtube::db($chan)" }
      }
    }
  }

  proc command { nick args } {
    set args [join [join $args]]
    if {$::debug} { puts "YOUTUBE : command used by $nick : [lindex $args 1] : [lrange $args 2 end]" }
    switch [lindex $args 1] {
      help {
        if {$::youtube::log} { ::irc::send ":$::irc::nick [tok PRIVMSG] $::irc::adminchan :\002YOUTUBE\002 $nick : help" }
        ::youtube::print_help $nick
        return
      }
      mode {
        set chan [string tolower [lindex $args 2]]
        set cmdmode [string tolower [lindex $args 3]]
        if {![::irc::is_chan $chan]} { ::irc::send ":$::irc::nick [tok NOTICE] $nick :You need to provide a chan in parameters."; return }
        if {![::irc::is_admin $nick]} { ::irc::send ":$::irc::nick [tok NOTICE] $nick :You are not admin."; return }
        set ::youtube::db $cmdmode
        forcelimit $chan
        saveDB
        ::irc::send ":$::irc::nick [tok NOTICE] $nick :Youtube mode for $chan is now $cmdmode"
        if {$::youtube::log} { ::irc::send ":$::irc::nick [tok PRIVMSG] $::irc::adminchan :\002YOUTUBE\002 $nick : mode $chan" }
        return
      }
      show {
        if {![::irc::is_admin $nick]} { ::irc::send ":$::irc::nick [tok NOTICE] $nick :You are not admin."; return }
        ::irc::send ":$::irc::nick [tok NOTICE] $nick :This is the configuration of the youtube module."
        ::irc::send ":$::irc::nick [tok NOTICE] $nick :The default configuration is $::youtube::mode"
        ::irc::send ":$::irc::nick [tok NOTICE] $nick :Channels specific configuration"
        foreach {index val} [array names ::youtube::db] {
          ::irc::send ":$::irc::nick [tok NOTICE] $nick :  \002$index\002 : $val"
        }
        if {$::youtube::log} { ::irc::send ":$::irc::nick [tok PRIVMSG] $::irc::adminchan :\002YOUTUBE\002 $nick : show" }
        return
      }
      default {
        ::youtube::print_help $nick
        return
      }
    }
    return
  }

  proc print_help { nick } {
    ::irc::send ":$::irc::nick [tok NOTICE] $nick :\002Youtube module help"
    ::irc::send ":$::irc::nick [tok NOTICE] $nick : "
    ::irc::send ":$::irc::nick [tok NOTICE] $nick :\002help\002                           : Print help"
    ::irc::send ":$::irc::nick [tok NOTICE] $nick :\002mode\002 <#chan> <none|light|full> : Change youtube configuration for <#chan>"
    ::irc::send ":$::irc::nick [tok NOTICE] $nick :\002show\002                           : Show the youtube configuration"
  return
  }

  proc loadDB { } {
    set f [open $::youtube::dbfile r]
    set content [read -nonewline $f]
    close $f
    if {[info exists ::youtube::db]} { unset $::youtube::db }
    foreach line [split $content "\n"] {
      lappend ::youtube::db([lindex $line 0]) [lindex $line 1]
    }
  }

  proc saveDB { } {
    set f [open $::youtube::dbfile w]
    foreach {index val} [array names ::youtube::db] {
      puts "$index $val"
      puts $f "$index $val"
    }
    close $f
  }

}

if {![file writable $::youtube::dbfile]} { if {[file exists $::youtube::dbfile]} { puts "$::youtube::dbfile is not writable. Please correct this."; exit } else { set f [open $::youtube::dbfile w]; close $f } }
::youtube::loadDB

# vim: set fenc=utf-8 sw=2 sts=2 ts=2 et filetype=tcl
