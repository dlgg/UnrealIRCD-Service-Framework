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
# Product name : Fantasy module for UnrealIRCD Service Framework
# Copyright (C) 2013 Damien Lesgourgues
# Author(s): Damien Lesgourgues
#
##############################################################################
puts [::msgcat::mc loadaddon "Fantasy commands"]

namespace eval fantasy {
# Register Master Bot Addon
  ::irc::hook_register privmsgchan "::fantasy::control"

  variable cmdchar $::irc::cmdchar
  namespace import ::tools::tok
}

proc ::fantasy::control { nick chan text } {
  if {$::debug==1} { puts "Fantasy : " }
  set textnc [::tools::stripmirc $text]

  if {[::tools::test [string index [lindex $textnc 0] 0] $::fantasy::cmdchar]} {
    set cmd [string range [lindex $textnc 0] 1 end]
    set paramsnc [join [lrange $textnc 1 end]]
    #set params [join [lrange $text 1 end]]
    # Commands for admins
    if {[::irc::is_admin $nick]} {
      switch $cmd {
        owner     { if {[lrange [join $textnc] 1 end]==""} { ::irc::send ":$::irc::nick [tok MODE] $chan +q $nick" } else { ::irc::send ":$::irc::nick [tok MODE] $chan +[string repeat q [llength $paramsnc]] $paramsnc" } }
        deowner   { if {[lrange [join $textnc] 1 end]==""} { ::irc::send ":$::irc::nick [tok MODE] $chan -q $nick" } else { ::irc::send ":$::irc::nick [tok MODE] $chan -[string repeat q [llength $paramsnc]] $paramsnc" } }
        protect   { if {[lrange [join $textnc] 1 end]==""} { ::irc::send ":$::irc::nick [tok MODE] $chan +a $nick" } else { ::irc::send ":$::irc::nick [tok MODE] $chan +[string repeat a [llength $paramsnc]] $paramsnc" } }
        deprotect { if {[lrange [join $textnc] 1 end]==""} { ::irc::send ":$::irc::nick [tok MODE] $chan -a $nick" } else { ::irc::send ":$::irc::nick [tok MODE] $chan -[string repeat a [llength $paramsnc]] $paramsnc" } }
        op        { if {[lrange [join $textnc] 1 end]==""} { ::irc::send ":$::irc::nick [tok MODE] $chan +o $nick" } else { ::irc::send ":$::irc::nick [tok MODE] $chan +[string repeat o [llength $paramsnc]] $paramsnc" } }
        deop      { if {[lrange [join $textnc] 1 end]==""} { ::irc::send ":$::irc::nick [tok MODE] $chan -o $nick" } else { ::irc::send ":$::irc::nick [tok MODE] $chan -[string repeat o [llength $paramsnc]] $paramsnc" } }
        halfop    { if {[lrange [join $textnc] 1 end]==""} { ::irc::send ":$::irc::nick [tok MODE] $chan +h $nick" } else { ::irc::send ":$::irc::nick [tok MODE] $chan +[string repeat h [llength $paramsnc]] $paramsnc" } }
        dehalfop  { if {[lrange [join $textnc] 1 end]==""} { ::irc::send ":$::irc::nick [tok MODE] $chan -h $nick" } else { ::irc::send ":$::irc::nick [tok MODE] $chan -[string repeat h [llength $paramsnc]] $paramsnc" } }
        voice     { if {[lrange [join $textnc] 1 end]==""} { ::irc::send ":$::irc::nick [tok MODE] $chan +v $nick" } else { ::irc::send ":$::irc::nick [tok MODE] $chan +[string repeat v [llength $paramsnc]] $paramsnc" } }
        devoice   { if {[lrange [join $textnc] 1 end]==""} { ::irc::send ":$::irc::nick [tok MODE] $chan -v $nick" } else { ::irc::send ":$::irc::nick [tok MODE] $chan -[string repeat v [llength $paramsnc]] $paramsnc" } }
      }
    }
    # Commands for all users
    switch $cmd {
      calin       { if {[lindex $textnc 1]==""} { ::irc::send ":$::irc::nick [tok NOTICE] $nick :Vous devez spécifier un pseudo pour cette commande." } else { ::irc::send ":$::irc::nick [tok PRIVMSG] $chan :\00313$nick\00310 câline tendrement \00306[lindex $textnc 1]\017." } }
      bisous      { if {[lindex $textnc 1]==""} { ::irc::send ":$::irc::nick [tok NOTICE] $nick :Vous devez spécifier un pseudo pour cette commande." } else { ::irc::send ":$::irc::nick [tok PRIVMSG] $chan :\00313$nick\00310 fait plein de gros bisous à \00306[lindex $textnc 1]\017." } }
      bise        { if {[lindex $textnc 1]==""} { ::irc::send ":$::irc::nick [tok NOTICE] $nick :Vous devez spécifier un pseudo pour cette commande." } else { ::irc::send ":$::irc::nick [tok PRIVMSG] $chan :\00313$nick\00310 fait la bise à \00306[lindex $textnc 1]\017." } }
      amour       { if {[lindex $textnc 1]==""} { ::irc::send ":$::irc::nick [tok NOTICE] $nick :Vous devez spécifier un pseudo pour cette commande." } else { ::irc::send ":$::irc::nick [tok PRIVMSG] $chan :\00313$nick\00310 ressent beaucoup d'amour pour \00306[lindex $textnc 1]\00310. Tu as de la chance, \00302tu sais\00310 ?\017" } }
      strip       { if {[lindex $textnc 1]==""} { ::irc::send ":$::irc::nick [tok NOTICE] $nick :Vous devez spécifier un pseudo pour cette commande." } else { ::irc::send ":$::irc::nick [tok PRIVMSG] $chan :\00313$nick\00310 mets de la musique, commence à se déshabiller sensuellement pour \00306[lindex $textnc 1]\00310. Tu va adorer ! \00302 \\o/\017" } }
      viol        { if {[lindex $textnc 1]==""} { ::irc::send ":$::irc::nick [tok NOTICE] $nick :Vous devez spécifier un pseudo pour cette commande." } else { ::irc::send ":$::irc::nick [tok PRIVMSG] $chan :\00313$nick\00310 déshabille à toute vitesse \00306[lindex $textnc 1]\00310, commence à lui sauter dessus et lui faire des choses bizarres...\017" } }
      clope       { if {[lindex $textnc 1]==""} { ::irc::send ":$::irc::nick [tok NOTICE] $nick :Vous devez spécifier un pseudo pour cette commande." } else { ::irc::send ":$::irc::nick [tok PRIVMSG] $chan :\00313$nick\00310 donne une cigarette à \00306[lindex $textnc 1]\00310. Tu veux quelle marque \00306[lindex $textnc 1]\00310 ? \00302Malboro\00310, \00302Luke\00310, \00302Basic\00310 ou encore \00302Phil Morris\00310 ?\00302 xD\017" } }
      bain        { if {[lindex $textnc 1]==""} { ::irc::send ":$::irc::nick [tok NOTICE] $nick :Vous devez spécifier un pseudo pour cette commande." } else { ::irc::send ":$::irc::nick [tok PRIVMSG] $chan :\00313$nick\00310 prends un bain mousseux avec \00306[lindex $textnc 1]\017." } }
      danse       { if {[lindex $textnc 1]==""} { ::irc::send ":$::irc::nick [tok NOTICE] $nick :Vous devez spécifier un pseudo pour cette commande." } else { ::irc::send ":$::irc::nick [tok PRIVMSG] $chan :\00313$nick\00310 prend la main de \00306[lindex $textnc 1]\00310 et l'entraine sur la piste de danse pour dandiner leur corps\017." } }
      fouette     { if {[lindex $textnc 1]==""} { ::irc::send ":$::irc::nick [tok NOTICE] $nick :Vous devez spécifier un pseudo pour cette commande." } else { ::irc::send ":$::irc::nick [tok PRIVMSG] $chan :\00313$nick\00310 fouette \00306[lindex $textnc 1]\017." } }
      massage     { if {[lindex $textnc 1]==""} { ::irc::send ":$::irc::nick [tok NOTICE] $nick :Vous devez spécifier un pseudo pour cette commande." } else { ::irc::send ":$::irc::nick [tok PRIVMSG] $chan :\00313$nick\00310 commence à masser le corps de \00306[lindex $textnc 1]\00310 sensuellement et tout doucement\017." } }
      leche       { if {[lindex $textnc 1]==""} { ::irc::send ":$::irc::nick [tok NOTICE] $nick :Vous devez spécifier un pseudo pour cette commande." } else { ::irc::send ":$::irc::nick [tok PRIVMSG] $chan :\00313$nick\00310 léchouilleuh \00306[lindex $textnc 1]\00310 sensuellement hummm... hot.\017" } }
      mord        { if {[lindex $textnc 1]==""} { ::irc::send ":$::irc::nick [tok NOTICE] $nick :Vous devez spécifier un pseudo pour cette commande." } else { ::irc::send ":$::irc::nick [tok PRIVMSG] $chan :\00313$nick\00310 mordilleuh doucement le cou de \00306[lindex $textnc 1]\00310 hummm...\017" } }
      bonbon      { if {[lindex $textnc 1]==""} { ::irc::send ":$::irc::nick [tok NOTICE] $nick :Vous devez spécifier un pseudo pour cette commande." } else { ::irc::send ":$::irc::nick [tok PRIVMSG] $chan :\00313$nick\00310 lance un bonbon à \00306[lindex $textnc 1]\017." } }
      touche      { if {[lindex $textnc 1]==""} { ::irc::send ":$::irc::nick [tok NOTICE] $nick :Vous devez spécifier un pseudo pour cette commande." } else { ::irc::send ":$::irc::nick [tok PRIVMSG] $chan :\00313$nick\00310 glisse sa main dans le string de \00313[lindex $text 1]\00310 et la caresse." } }
      pipe        { if {[lindex $textnc 1]==""} { ::irc::send ":$::irc::nick [tok NOTICE] $nick :Vous devez spécifier un pseudo pour cette commande." } else { ::irc::send ":$::irc::nick [tok PRIVMSG] $chan :\00313$nick\00310 prend le sexe de \00313[lindex $text 1]\00310 en bouche et le suce." } }
      cuni        { if {[lindex $textnc 1]==""} { ::irc::send ":$::irc::nick [tok NOTICE] $nick :Vous devez spécifier un pseudo pour cette commande." } else { ::irc::send ":$::irc::nick [tok PRIVMSG] $chan :\00313$nick\00310 retire le shorty de \00313[lindex $text 1]\00310 et viens jouer avec sa langue entre ses lèvres intimes." } }
    }
  }
}

# vim: set fenc=utf-8 sw=2 sts=2 ts=2 et filetype=tcl
