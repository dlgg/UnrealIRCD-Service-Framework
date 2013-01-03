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

set chars { 0 1 2 3 4 5 6 7 8 9 A B C D E F G H I J K L M N O P Q R S T U V W X Y Z a b c d e f g h i j k l m n o p q r s t u v w x y z \{ \} }

proc dec2base { num baselist } {
  set res {}
  set base [llength $baselist]
  while {$num/$base != 0} {
    set rest [expr { $num % $base } ]
    set res [lindex $baselist $rest]$res
    set num [expr { $num / $base } ]
  }
  set res [lindex $baselist $num]$res
  return $res
}

proc base2dec { num baselist } {
  set sum 0
  foreach char [split $num ""] {
    set d [lsearch $baselist $char]
    if {$d == -1} {error "invalid unrealbase-64 digit '$char' in $num"}
    set sum [expr {$sum * 64 + $d}]
  }
  return $sum
}

set test "4 42 51 62 123 127 142 187 200 242"
puts "we need to obtain : 4 g p \{ 1x 1\} 2E 2x 38 3o"

foreach value $test {
  set tobase [dec2base $value $chars]
  set revert [base2dec $tobase $chars]
  puts "Test de conversion de $value : $tobase $revert"
}
