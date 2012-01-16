#!/usr/bin/env tclsh

variable ::mysock
array set ::mysock {
  game "poker"
  root "dlgg"
  hostname "tcl.hebeo.fr"
}

namespace eval poker {
  namespace export *
  # Parametres pour le jeu Poker
  variable nick "Poker"
  variable username "poker"
  variable hostname "poker.$::mysock(hostname)"
  variable realname "Bot de jeu Poker"
  variable chan "#Poker"

  proc getnick     {} { return $::poker::nick }
  proc getusername {} { return $::poker::username }
  proc gethostname {} { return $::poker::hostname }
  proc getrealname {} { return $::poker::realname }
  proc getchan     {} { return $::poker::chan }
}

proc ::poker::control_priv { nick text } {
  puts "PROC POKER PRIV : $nick - $text"
}
proc ::poker::control_pub { nick text } {
  puts "PROC POKER PUB  : $nick - $text"
}

puts "Test of $::mysock(game) by $::mysock(root)"

puts "1: var | 2: proc in eval | 3 : proc outside | 4 : dynamic var"
puts "1 nick      : $::poker::nick"
puts "1 username  : $::poker::username"
puts "1 hostname  : $::poker::hostname"
puts "1 realname  : $::poker::realname"
puts "2 nick      : [::poker::getnick]"
puts "2 username  : [::poker::getusername]"
puts "2 hostname  : [::poker::gethostname]"
puts "2 realname  : [::poker::getrealname]"
puts "3 priv      : "
::poker::control_priv $::mysock(root) [list $::mysock(game) $::mysock(hostname) ]
puts "3 pub       : "
::poker::control_pub  $::mysock(root) [list $::mysock(game) $::mysock(hostname) ]

set varname "::$::mysock(game)::nick"
puts "4 nick      : [set $varname]"
puts "4 nick      : [set ::$::mysock(game)::nick]"
