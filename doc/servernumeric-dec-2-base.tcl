#!/usr/bin/env tclsh

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
