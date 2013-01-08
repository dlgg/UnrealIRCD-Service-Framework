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
# Product name : Uno Game for UnrealIRCD Service Framework
# Copyright (C) 2013 Damien Lesgourgues
# Author(s): Damien Lesgourgues
# Based on UNO bot by Marky v0.96
#
##############################################################################
#
# Marky's Uno v0.96
# Copyright (C) 2004 Mark A. Day (techwhiz@earthlink.net)
#
# Uno(tm) is Copyright (C) 2001 Mattel, Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
##############################################################################
# TODO
#
# - Cron system for eset of scores every month
# - recode AutoSkipTimer system for nexting a player if it don't play in the
#   next 2 minutes
##############################################################################

puts [::msgcat::mc loadgame "UNO"]

# Parametres pour le jeu UNO
namespace eval uno {
  namespace import ::tools::tok ::tools::is_oper

  variable nick       "UNO"
  variable username   "uno"
  variable hostname   "uno.$::irc::hostname"
  variable realname   "Bot de jeu UNO"
  variable chan       "#UNO"

# Game variables
  variable Chan         $chan
  variable Robot        $nick
  variable PointsName   "Points"
  variable StopAfter    5
  variable Bonus        1000
  variable WildDrawTwos 1
  variable CFGFile      "files/uno.cfg"
  variable ScoreFile    "files/UnoScores"
  variable MaxNickLen   32
  variable MaxPlayers   8
  variable NTC          "[tok NOTICE]"

  # Global Variables
  variable On             0
  variable Mode           0
  variable Paused         0
  variable Players        0
  variable MasterDeck     ""
  variable Deck           ""
  variable DiscardPile    ""
  variable PlayCard       ""
  variable RoundRobin     ""
  variable ThisPlayer     ""
  variable ThisPlayerIDX  0
  variable StartTime      [::tools::unixtime]
  variable IsColorChange  0
  variable ColorPicker    ""
  variable IsDraw         0
  variable IDX            ""
  variable UnPlayedRounds 0
  
  # Scores Records And Ads
  variable LastMonthCards
  variable LastMonthGames
  set LastMonthCards(0) "Personne 0"
  set LastMonthCards(1) "Personne 0"
  set LastMonthCards(2) "Personne 0"
  set LastMonthGames(0) "Personne 0"
  set LastMonthGames(1) "Personne 0"
  set LastMonthGames(2) "Personne 0"
  variable Fast              "Personne 600"
  variable High              "Personne 0"
  variable Played            "Personne 0"
  variable RecordHigh        "Personne 0"
  variable RecordFast        "Personne 600"
  variable RecordCard        "Personne 0"
  variable RecordWins        "Personne 0"
  variable RecordPlayed      "Personne 0"
  variable AdNumber          0
  
  # Card Stats
  variable CardStats
  set CardStats(played) 0
  set CardStats(passed) 0
  set CardStats(drawn) 0
  set CardStats(wilds) 0
  set CardStats(draws) 0
  set CardStats(skips) 0
  set CardStats(revs) 0
  
  # Timers
  variable StartTimer ""
  variable SkipTimer ""
  variable CycleTimer ""
  variable BotTimer ""
  
  # Grace periods and timeouts
  # AutoSkip period can be raised but not lower than 2
  variable AutoSkipPeriod 2
  variable StartGracePeriod 10
  variable RobotRestartPeriod 1
  variable CycleTime 30
  
  # Nick colours
  variable NickColour "06 13 03 07 12 10 04 11 09 08"
  
  # Debugging info
  variable Debug $::debug
  variable Version "0.96.74.3"

  # Don't modify this
  ::irc::hook_register privmsg-[string tolower $chan] "::uno::controlpub"
  ::irc::hook_register privmsg-[string tolower $nick] "::uno::controlpriv"
  #::irc::hook_register join-[string tolower $chan]    "::uno::controljoin"
  ::irc::hook_register sync                           "::uno::controlsync"

}

proc ::uno::controlsync {} { ::irc::bot_init $::uno::nick $::uno::username $::uno::hostname $::uno::realname ; ::irc::join_chan $::uno::nick $::uno::chan }
proc ::uno::controlinit {} { ::irc::hook_register join-[string tolower $chan] "::uno::controljoin" }
proc ::uno::controljoin { nick } { ::irc::send ":$::uno::nick [tok NOTICE] $nick :[::msgcat::mc uno_welcome [::uno::ad]]" }
proc ::uno::controlpriv { nick text } { if {$::debug==1} { ::irc::send ":$::uno::nick [tok PRIVMSG] $::uno::chan :\002PRIV\002 $nick > [join $text]" } }

proc ::uno::controlpub { nick text } {
  # nick uhost hand chan arg
  #if {$::debug==1} { ::irc::send ":$::uno::nick [tok PRIVMSG] $::uno::chan :\002PUB \002 $nick > [join $text]" }
  switch [lindex $text 0] {
    !uno-reset   { ::uno::Reset; set ::uno::On 0 }
    !uno         { ::uno::Init         $nick "none" "-" $::uno::chan "$text" }
    !unocmds     { ::uno::Cmds         $nick "none" "-" $::uno::chan "$text" }
    !remove      { ::uno::Remove       $nick "none" "-" $::uno::chan "$text" }
    !pause       { ::uno::Pause        $nick "none" "-" $::uno::chan "$text" }
    !unowon      { ::uno::Won          $nick "none" "-" $::uno::chan "$text" }
    !unotop10    { ::uno::TopTen       $nick "none" "-" $::uno::chan "$text" }
    !unotop10won { ::uno::TopTenWon    $nick "none" "-" $::uno::chan "$text" }
    !unotop3last { ::uno::TopThreeLast $nick "none" "-" $::uno::chan "$text" }
    !unofast     { ::uno::TopFast      $nick "none" "-" $::uno::chan "$text" }
    !unohigh     { ::uno::HighScore    $nick "none" "-" $::uno::chan "$text" }
    !unoplayed   { ::uno::Played       $nick "none" "-" $::uno::chan "$text" }
    !unorecords  { ::uno::Records      $nick "none" "-" $::uno::chan "$text" }
    !unoversion  { ::uno::Version      $nick "none" "-" $::uno::chan "$text" }
    !stop        { ::uno::Stop         $nick "none" "-" $::uno::chan "$text" }
  }
  if {($::uno::On != 0)&&($::uno::Paused == 0)} {
    switch [lindex $text 0] {
      join  -
      jo    -
      !jo   { ::uno::Join        $nick "none" "-" $::uno::chan "$text" }
      order -
      od    -
      !od   { ::uno::Order       $nick "none" "-" $::uno::chan "$text" }
      time  -
      ti    -
      !ti   { ::uno::Time        $nick "none" "-" $::uno::chan "$text" }
      cards -
      ca    -
      !ca   { ::uno:ShowCards    $nick "none" "-" $::uno::chan "$text" }
      play  -
      pl    -
      !pl   { ::uno::PlayCard    $nick "none" "-" $::uno::chan "$text" }
      card  -
      cd    -
      !cd   { ::uno::TopCard     $nick "none" "-" $::uno::chan "$text" }
      turn  -
      tu    -
      !tu   { ::uno::Turn        $nick "none" "-" $::uno::chan "$text" }
      draw  -
      dr    -
      !dr   { ::uno::Draw        $nick "none" "-" $::uno::chan "$text" }
      color -
      co    -
      !co   { ::uno::ColorChange $nick "none" "-" $::uno::chan "$text" }
      pass  -
      pa    -
      !pa   { ::uno::Pass        $nick "none" "-" $::uno::chan "$text" }
      count -
      ct    -
      !ct   { ::uno::Count       $nick "none" "-" $::uno::chan "$text" }
      stats -
      st    -
      !st   { ::uno::CardStats   $nick "none" "-" $::uno::chan "$text" }
    }
  }
}

#
# Starting game
#
proc ::uno::Init {nick uhost hand chan arg} {
  if {$::debug==1} { puts [::msgcat::mc uno_unocmd $nick $chan] }
  if {$::uno::On > 0} {
    if {$chan != $::uno::Chan} { ::irc::send ":$::uno::nick [tok PRIVMSG] $chan :[::msgcat::mc uno_startalready0 [::uno::ad]]" }
    if {$chan == $::uno::Chan} { ::irc::send ":$::uno::nick [tok PRIVMSG] $chan :[::msgcat::mc uno_startalready1 [::uno::ad]]" }
    return
  }
  set ::uno::chan $chan
  if {$::debug==1} { puts [::msgcat::mc uno_started $chan] }
  ::uno::msg "[::uno::ad] \00304\[\00310$nick\00304\]\003"
  set ::uno::On 1
  ::uno::WriteCFG
  ::uno::Next
  return
}

#
# Initialize a new game
#
proc ::uno::Next {} {
  if {$::uno::On == 0} {return}
  ::uno::Reset
  set ::uno::Mode 1
  set ::uno::MasterDeck [list B0 B1 B1 B2 B2 B3 B3 B4 B4 B5 B5 B6 B6 B7 B7 B8 B8 B9 B9 BR BR BS BS BDT BDT R0 R1 R1 R2 R2 R3 R3 R4 R4 R5 R5 R6 R6 R7 R7 R8 R8 R9 R9 RR RR RS RS RDT RDT Y0 Y1 Y1 Y2 Y2 Y3 Y3 Y4 Y4 Y5 Y5 Y6 Y6 Y7 Y7 Y8 Y8 Y9 Y9 YR YR YS YS YDT YDT G0 G1 G1 G2 G2 G3 G3 G4 G4 G5 G5 G6 G6 G7 G7 G8 G8 G9 G9 GR GR GS GS GDT GDT W W W W WDF WDF WDF WDF]
  set ::uno::Deck ""

  set ::uno::newrand [expr srand([::tools::unixtime])]
  while {[llength $::uno::Deck] != 108} {
    set pcardnum [expr {int(rand()*[llength $::uno::MasterDeck])}]
    set pcard [lindex $::uno::MasterDeck $pcardnum]
    lappend ::uno::Deck $pcard
    set ::uno::MasterDeck [lreplace $::uno::MasterDeck $pcardnum $pcardnum]
  }
  if [info exist ::uno::Hand] {unset ::uno::Hand}
  if [info exist ::uno::NickColor] {unset ::uno::NickColor}
  ::uno::msg [::msgcat::mc uno_pubjoin [::uno::ad] $::uno::StartGracePeriod]
  set ::uno::StartTimer [after [expr {int($::uno::StartGracePeriod * 1000)}] ::uno::Start]
  if {$::debug==1} { puts "[after info]" }
  return
}

#
# Start a new game
#
proc ::uno::Start {} {
  if {$::uno::On == 0} {return}
  if {[llength $::uno::RoundRobin] == 0} {
    ::uno::msg [::msgcat::mc uno_noplayers [::uno::ad] $::uno::CycleTime]
    incr UnPlayedRounds
    if {($::uno::StopAfter > 0)&&($UnPlayedRounds >= $::uno::StopAfter)} {
      ::uno::msg [::msgcat::mc uno_stopnoplayers [::uno::ad] $::uno::StopAfter]
      set ::uno::On 0
      after 1000 "::uno::Stop $::uno::Robot $::uno::Robot none $::uno::Chan none"
      return
    }
    ::uno::Cycle
    return
  }

  # Bot Joins If One Player
  if {[llength $::uno::RoundRobin] == 1} {
    incr ::uno::Players
    lappend ::uno::RoundRobin "$::uno::Robot"
    lappend ::uno::IDX "$::uno::Robot"
    if [info exist ::uno::Hand($::uno::Robot)] {unset ::uno::Hand($::uno::Robot)}
    if [info exist ::uno::NickColor($::uno::Robot)] {unset ::uno::NickColor($::uno::Robot)}
    set ::uno::Hand($::uno::Robot) ""
    set ::uno::NickColor($::uno::Robot) [::uno::colornick $::uno::Players]
    ::uno::msg [::msgcat::mc uno_join0 [::uno::nikclr $::uno::Robot] [::uno::ad]]
    if {$::debug==1} { puts [::msgcat::mc uno_join1 $::uno::Robot] }
    ::uno::Shuffle 7

    while {[llength $::uno::Hand($::uno::Robot)] != 7} {
      set pcardnum [expr {int(rand() * [llength $::uno::Deck])}]
      set pcard [lindex $::uno::Deck $pcardnum]
      set ::uno::Deck [lreplace ${::uno::Deck} $pcardnum $pcardnum]
      lappend ::uno::Hand($::uno::Robot) "$pcard"
    }
    if {$::debug > 1} { ::uno::log $::uno::Robot $::uno::Hand($::uno::Robot) }
  }
  ::uno::msg [::msgcat::mc uno_welcome0 [::uno::ad]]
  ::uno::msg [::msgcat::mc uno_welcome1 $::uno::Players $::uno::RoundRobin]
  set ::uno::Mode 2
  set ::uno::ThisPlayer [lindex $::uno::RoundRobin 0]

  # Draw Card From Deck - First Top Card
  set ::uno::DiscardPile ""
  set pcardnum [expr {int(rand() * [llength $::uno::Deck])}]
  set pcard [lindex $::uno::Deck $pcardnum]

  # Play Doesnt Start With A Wild Card
  while {[string range $pcard 0 0] == "W"} {
    set pcardnum [expr {int(rand() * [llength $::uno::Deck])}]
    set pcard [lindex $::uno::Deck $pcardnum]
  }

  set ::uno::PlayCard $pcard
  set ::uno::Deck [lreplace ${::uno::Deck} $pcardnum $pcardnum]
  set Card [::uno::CardColor $pcard]
  ::uno::msg [::msgcat::mc uno_start [::uno::nikclr $::uno::ThisPlayer] $Card]
  set Card [::uno::CardColorAll $::uno::ThisPlayer]
  ::uno::showcards $::uno::ThisPlayerIDX $Card
  set ::uno::StartTime [::tools::unixtime]

  # Start Auto-Skip Timer
  ### set ::uno::SkipTimer [after [expr {int($::uno::AutoSkipPeriod*1000*60)}] ::uno::AutoSkip]
  set ::uno::UnPlayedRounds 0
  return
}

#
# Stop a game
#
proc ::uno::Stop {nick uhost hand chan arg} {
  if {$chan != $::uno::Chan} {return}
  catch {after cancel $::uno::StartTimer}
  ### catch {after cancel $::uno::SkipTimer}
  catch {after cancel $::uno::CycleTimer}
  ::uno::msg [::msgcat::mc uno_stop0 [::uno::ad] $nick]
  if {$::debug==1} { puts [::msgcat::mc uno_stop1 $nick $chan] }
  set ::uno::On 0
  set ::uno::Paused 0
  set ::uno::UnPlayedRounds 0
  ::uno::Reset
  return
}

#
# Cycle a new game
#
proc ::uno::Cycle {} {
  if {$::uno::On == 0} {return}
  set ::uno::Mode 4
  ### catch {after cancel $::uno::SkipTimer}
  set ::uno::AdTime [expr $::uno::CycleTime /2]
  set ::uno::AdTimer [after [expr {int($::uno::AdTime*1000)}] ::uno::ScoreAdvertise]
  set ::uno::CycleTimer [after [expr {int($::uno::CycleTime*1000)}] ::uno::Next]
  return
}

#
# Add a player
#
proc ::uno::Join {nick uhost hand chan arg} {
  if {($chan != $::uno::Chan)||($::uno::Mode < 1)||($::uno::Mode > 2)} {return}
  if {[llength $::uno::RoundRobin] == $::uno::MaxPlayers} {
    ::uno::ntc $nick [::msgcat::mc uno_maxplayers $nick]
    return
  }
  set pcount 0
  while {[lindex $::uno::RoundRobin $pcount] != ""} {
    if {[lindex $::uno::RoundRobin $pcount] == $nick} {
      return
    }
    incr pcount
  }
  incr ::uno::Players
  lappend ::uno::RoundRobin $nick
  lappend ::uno::IDX $nick
  if [info exist ::uno::Hand($nick)] {unset ::uno::Hand($nick)}
  if [info exist ::uno::NickColor($nick)] {unset ::uno::NickColor($nick)}
  set ::uno::Hand($nick) ""
  set ::uno::NickColor($nick) [colornick $::uno::Players]
  # Re-Shuffle Deck
  ::uno::Shuffle 7
  # Deal Cards To Player
  set Card ""
  while {[llength $::uno::Hand($nick)] != 7} {
    set pcardnum [expr {int(rand() * [llength $::uno::Deck])}]
    set pcard [lindex $::uno::Deck $pcardnum]
    set ::uno:Deck [lreplace ${::uno::Deck} $pcardnum $pcardnum]
    lappend ::uno::Hand($nick) $pcard
    append Card [::uno::CardColor $pcard]
  }
  if {$::debug > 1} { ::uno::log $nick $::uno::Hand($nick) }
  ::uno::msg [::msgcat::mc uno_pljoin0 [::uno::nikclr $nick] [::uno::ad]]
  puts [::msgcat::mc uno_pljoin1 $nick]
  ::uno::ntc $nick [::msgcat::mc uno_inhand $Card]
  return
}

#
# Reset Game Variables
#
proc ::uno::Reset {} {
  set ::uno::Mode 0
  set ::uno::Paused 0
  set ::uno::Players 0
  set ::uno::MasterDeck ""
  set ::uno::Deck ""
  set ::uno::DiscardPile ""
  set ::uno::RoundRobin ""
  set ::uno::ThisPlayer ""
  set ::uno::ThisPlayerIDX 0
  set ::uno::PlayCard ""
  set ::uno::IsColorChange 0
  set ::uno::ColorPicker ""
  set ::uno::IsDraw 0
  set ::uno::IDX ""
  set ::uno::AdNumber 0

  set ::uno::CardStats(played) 0
  set ::uno::CardStats(passed) 0
  set ::uno::CardStats(drawn) 0
  set ::uno::CardStats(wilds) 0
  set ::uno::CardStats(draws) 0
  set ::uno::CardStats(skips) 0
  set ::uno::CardStats(revs) 0

  set ::uno::StartTimer ""
  set ::uno::SkipTimer ""
  set ::uno::CycleTimer ""

  return
}

#
# Add card(s) to players hand
#
proc ::uno::AddDrawToHand {cplayer idx num} {
  # Check if deck needs reshuffling
  ::uno::Shuffle $num
  set Card ""
  set newhand [expr [llength $::uno::Hand($cplayer)] + $num]
  while {[llength $::uno::Hand($cplayer)] != $newhand} {
    set pcardnum [expr {int(rand() * [llength $::uno::Deck])}]
    set pcard [lindex $::uno::Deck $pcardnum]
    set ::uno::Deck [lreplace ${::uno::Deck} $pcardnum $pcardnum]
    lappend ::uno::Hand($cplayer) $pcard
    append Card [::uno::CardColor $pcard]
  }
  ::uno::showdraw $idx $Card
  incr ::uno::CardStats(drawn) $num
}

#
# Remove played card from player's hand
#
proc ::uno::RemoveCardFromHand {cplayer pcard} {
  set ::uno::Hand($cplayer) [lreplace $::uno::Hand($cplayer) $pcard $pcard]
}

#
# Add card to discard pile
#
proc ::uno::AddToDiscardPile {playcard} {
  if {[string range $playcard 1 1] != ""} {
    lappend ::uno::DiscardPile $playcard
  }
}

#
# Draw a card
#
proc ::uno::Draw {nick uhost hand chan arg} {
  if {($chan != $::uno::Chan)||($::uno::Mode != 2)||($nick != $::uno::ThisPlayer)} {return}
  if {$::uno::IsDraw == 0} {
    set ::uno::IsDraw 1
    ::uno::Shuffle 1
    set dcardnum [expr {int(rand() * [llength $::uno::Deck])}]
    set dcard [lindex $::uno::Deck $dcardnum]
    lappend ::uno::Hand($nick) $dcard
    set ::uno::Deck [lreplace ${::uno::Deck} $dcardnum $dcardnum]
    append Card [::uno::CardColor $dcard]
    ::uno::showdraw $::uno::ThisPlayerIDX $Card
    ::uno::showwhodrew $nick
    incr ::uno::CardStats(drawn)
    ::uno::AutoSkipReset
    return
  }
  ::uno::ntc $nick [::msgcat::mc uno_alreadypick]
  ::uno::AutoSkipReset
  return
}

#
# Pass a turn
#
proc ::uno::Pass {nick uhost hand chan arg} {
  if {($chan != $::uno::Chan)||($::uno::Mode != 2)} {return}
  if {($nick != $::uno::ThisPlayer)||($::uno::IsColorChange == 1)} {return}
  ::uno::AutoSkipReset
  if {$::uno::IsDraw == 1} {
    incr ::uno::CardStats(passed)
    set ::uno::IsDraw 0
    ::uno::NextPlayer
    ::uno::playpass $nick $::uno::ThisPlayer
    set Card [::uno::CardColorAll $::uno::ThisPlayer]
    ::uno::showcards $::uno::ThisPlayerIDX $Card
    ::uno::RobotRestart
  } {
    ::uno::ntc $nick [::msgcat::mc uno_pickbeforepass $nick]
  }
  return
}

#
# Color change
#
proc ::uno::ColorChange {nick uhost hand chan arg} {
  if {($chan != $::uno::Chan)||($::uno::Mode != 2)} {return}
  if {($nick != $::uno::ColorPicker)||($::uno::IsColorChange == 0)} {return}
  ::uno::AutoSkipReset
  regsub -all \[`.,!{}\ ] $arg "" arg
  set NewColor [string toupper [string range $arg 2 2]]
  if {$::debug == 1} {
    puts "arg : $arg"
    puts "Asked Color : $NewColor"
  }
  switch $NewColor {
    "B" { set ::uno::PlayCard "B"; set Card " \00300,12 [::msgcat::mc uno_blue] \003 "}
    "G" { set ::uno::PlayCard "G"; set Card " \00300,03 [::msgcat::mc uno_green] \003 "}
    "Y" { set ::uno::PlayCard "Y"; set Card " \00301,08 [::msgcat::mc uno_yellow] \003 "}
    "R" { set ::uno::PlayCard "R"; set Card " \00300,04 [::msgcat::mc uno_red] \003 "}
    default { ::uno::ntc $nick [::msgcat::mc uno_selectcolor]; return }
  }
  ::uno::NextPlayer
  ::uno::msg [::msgcat::mc uno_selectedcolor [::uno::nikclr $::uno::ColorPicker] $Card [::uno::nikclr $::uno::ThisPlayer]]
  set Card [::uno::CardColorAll $::uno::ThisPlayer]
  ::uno::showcards $::uno::ThisPlayerIDX $Card
  set ::uno::ColorPicker ""
  set ::uno::IsColorChange 0
  set ::uno::IsDraw 0
  ::uno::RobotRestart
  return
}

#
# Skip card
#
proc ::uno::PlayUnoSkipCard {nick pickednum crd} {
  set c0 [string range $crd 0 0]
  set c1 [string range $crd 1 1]
  set cip0 [string range $::uno::PlayCard 0 0]
  set cip1 [string range $::uno::PlayCard 1 1]
  if {$c1 != "S"} {return 0}
  if {($c0 != $cip0)&&($c1 != $cip1)} {return 0}
  incr ::uno::CardStats(played)
  incr ::uno::CardStats(skips)
  ::uno::AddToDiscardPile $::uno::PlayCard
  ::uno::RemoveCardFromHand $nick $pickednum
  set ::uno::PlayCard $crd
  set Card [::uno::CardColor $crd]
  set SkipPlayer $::uno::ThisPlayer
  ::uno::NextPlayer
  set SkippedPlayer [lindex $::uno::RoundRobin $::uno::ThisPlayerIDX]
  ::uno::NextPlayer
  # No Cards Left = Winner
  if {[::uno::check_unowin $SkipPlayer $Card] > 0} {
    ::uno::showwin $SkipPlayer $Card
    ::uno::Win $SkipPlayer
    ::uno::Cycle
    return 1
  }
  ::uno::playskip $nick $Card $SkippedPlayer $::uno::ThisPlayer
  ::uno::check_hasuno $SkipPlayer
  set Card [::uno::CardColorAll $::uno::ThisPlayer]
  ::uno::showcards $::uno::ThisPlayerIDX $Card
  set ::uno::IsDraw 0
  return 1
}

#
# Reverse card
#
proc ::uno::PlayUnoReverseCard {nick pickednum crd} {
  set c0 [string range $crd 0 0]
  set c1 [string range $crd 1 1]
  set cip0 [string range $::uno::PlayCard 0 0]
  set cip1 [string range $::uno::PlayCard 1 1]
  if {$c1 != "R"} {return 0}
  if {($c0 != $cip0)&&($c1 != $cip1)} {return 0}
  incr ::uno::CardStats(played)
  incr ::uno::CardStats(revs)
  ::uno::AddToDiscardPile $::uno::PlayCard
  ::uno::RemoveCardFromHand $nick $pickednum
  set ::uno::PlayCard $crd
  set Card [::uno::CardColor $crd]
  # Reverse RoundRobin and Move To Next Player
  set NewRoundRobin ""
  set OrigOrderLength [llength $::uno::RoundRobin]
  set IDX $OrigOrderLength
  while {$OrigOrderLength != [llength $NewRoundRobin]} {
    set IDX [expr ($IDX - 1)]
    lappend NewRoundRobin [lindex $::uno::RoundRobin $IDX]
  }
  set Newindexorder ""
  set OrigindexLength [llength $::uno::IDX]
  set IDX $OrigindexLength
  while {$OrigindexLength != [llength $Newindexorder]} {
    set IDX [expr ($IDX - 1)]
    lappend Newindexorder [lindex $::uno::IDX $IDX]
  }
  set ::uno::IDX $Newindexorder
  set ::uno::RoundRobin $NewRoundRobin
  set ReversePlayer $::uno::ThisPlayer
  # Next Player After Reversing RoundRobin
  set pcount 0
  while {$pcount != [llength $::uno::RoundRobin]} {
    if {[lindex $::uno::RoundRobin $pcount] == $::uno::ThisPlayer} {
      set ::uno::ThisPlayerIDX $pcount
      break
    }
    incr pcount
  }
  # <3 Players Act Like A Skip Card
  if {[llength $::uno::RoundRobin] > 2} {
    incr ::uno::ThisPlayerIDX
    if {$::uno::ThisPlayerIDX >= [llength $::uno::RoundRobin]} {set ::uno::ThisPlayerIDX 0}
  }
  set ::uno::ThisPlayer [lindex $::uno::RoundRobin $::uno::ThisPlayerIDX]
  # No Cards Left = Winner
  if {[::uno::check_unowin $ReversePlayer $Card] > 0} {
    ::uno::showwin $ReversePlayer $Card
    ::uno::Win $ReversePlayer
    ::uno::Cycle
    return 1
  }
  ::uno::playcard $nick $Card $::uno::ThisPlayer
  ::uno::check_hasuno $ReversePlayer
  set Card [::uno::CardColorAll $::uno::ThisPlayer]
  ::uno::showcards $::uno::ThisPlayerIDX $Card
  set ::uno::IsDraw 0
  return 1
}

#
# Draw Two card
#
proc ::uno::PlayUnoDrawTwoCard {nick pickednum crd} {
  set CardOk 0
  set c0 [string range $crd 0 0]
  set c2 [string range $crd 2 2]
  set cip0 [string range $::uno::PlayCard 0 0]
  set cip1 [string range $::uno::PlayCard 1 1]
  set cip2 [string range $::uno::PlayCard 2 2]
  if {$c2 != "T"} {return 0}
  if {$c0 == $cip0} {set CardOk 1}
  if {$cip2 == "T"} {set CardOk 1}
  if {$::uno::WildDrawTwos != 0} {
    if {($cip1 != "")&&($cip2 != "F")} {set CardOk 1}
  }
  if {$CardOk == 1} {
    incr ::uno::CardStats(draws)
    incr ::uno::CardStats(played)
    ::uno::AddToDiscardPile $::uno::PlayCard
    ::uno::RemoveCardFromHand $nick $pickednum
    set ::uno::PlayCard $crd
    set Card [CardColor $crd]
    set DrawPlayer $::uno::ThisPlayer
    set DrawPlayerIDX $::uno::ThisPlayerIDX
    # Move to the player that draws
    ::uno::NextPlayer
    set PlayerThatDrew $::uno::ThisPlayer
    set PlayerThatDrewIDX $::uno::ThisPlayerIDX
    # Move To The Next Player
    ::uno::NextPlayer
    if {[::uno::check_unowin $nick $Card] > 0} {
      ::uno::AddDrawToHand $PlayerThatDrew $PlayerThatDrewIDX 2
      ::uno::showwin $nick $Card
      ::uno::Win $nick
      ::uno::Cycle
      return 1
    }
    ::uno::playdraw $nick $Card $PlayerThatDrew $::uno::ThisPlayer
    ::uno::AddDrawToHand $PlayerThatDrew $PlayerThatDrewIDX 2
    ::uno::check_hasuno $nick
    set Card [::uno::CardColorAll $::uno::ThisPlayer]
    ::uno::showcards $::uno::ThisPlayerIDX $Card
    set ::uno::IsDraw 0
    return 1
  }
  return 0
}

#
# Wild Draw Four card
#
proc ::uno::PlayUnoWildDrawFourCard {nick pickednum crd isrobot} {
  if {[string range $crd 2 2] != "F"} {return 0}
  incr ::uno::CardStats(wilds)
  incr ::uno::CardStats(played)
  set ::uno::ColorPicker $::uno::ThisPlayer
  ::uno::AddToDiscardPile $::uno::PlayCard
  ::uno::RemoveCardFromHand $nick $pickednum
  set ::uno::PlayCard $crd
  set Card [::uno::CardColor $crd]
  # move to the player that draws
  ::uno::NextPlayer
  set PlayerThatDrew $::uno::ThisPlayer
  set PlayerThatDrewIDX $::uno::ThisPlayerIDX
  if {$isrobot > 0} {
    # choose color and move to next player
    set cip [::uno::BotPickAColor]
    ::uno::NextPlayer
  }
  if {[::uno::check_unowin $nick $Card] > 0} {
    ::uno::AddDrawToHand $PlayerThatDrew $PlayerThatDrewIDX 4
    ::uno::showwin $nick $Card
    ::uno::Win $nick
    ::uno::Cycle
    return 1
  }
  if {$isrobot > 0} {
    ::uno::botplaywildfour $::uno::ColorPicker $PlayerThatDrew $::uno::ColorPicker $cip $::uno::ThisPlayer
    set ::uno::ColorPicker ""
    set ::uno::IsColorChange 0
  } {
    ::uno::playwildfour $nick $PlayerThatDrew $::uno::ColorPicker
    set ::uno::IsColorChange 1
  }
  ::uno::AddDrawToHand $PlayerThatDrew $PlayerThatDrewIDX 4
  ::uno::check_hasuno $nick
  if {$isrobot > 0} {
    set Card [::uno::CardColorAll $::uno::ThisPlayer]
    ::uno::showcards $::uno::ThisPlayerIDX $Card
  }
  set ::uno::IsDraw 0
  return 1
}

#
# Wild card
#
proc ::uno::PlayUnoWildCard {nick pickednum crd isrobot} {
  if {[string range $crd 0 0] != "W"} {return 0}
  incr ::uno::CardStats(wilds)
  incr ::uno::CardStats(played)
  set ::uno::ColorPicker $::uno::ThisPlayer
  ::uno::AddToDiscardPile $::uno::PlayCard
  ::uno::RemoveCardFromHand $nick $pickednum
  set ::uno::PlayCard $crd
  set Card [::uno::CardColor $crd]
  # Ok to remove this?
  #set ::uno::ThisPlayer [lindex $::uno::RoundRobin $::uno::ThisPlayerIDX]
  #set DrawnPlayer $::uno::ThisPlayer
  if {$isrobot > 0} {
    # Make A Color Choice
    set cip [::uno::BotPickAColor]
    ::uno::NextPlayer
  }
  # No Cards Left = Winner
  if {[check_unowin $nick $Card] > 0} {
    ::uno::showwin $nick $Card
    ::uno::Win $nick
    ::uno::Cycle
    return 1
  }
  if {$isrobot > 0} {
    ::uno::botplaywild $nick $::uno::ColorPicker $cip $::uno::ThisPlayer
    set ::uno::ColorPicker ""
    set Card [::uno::CardColorAll $::uno::ThisPlayer]
    ::uno::showcards $::uno::ThisPlayerIDX $Card
    set ::uno::IsColorChange 0
  } {
    ::uno::playwild $nick $::uno::ColorPicker
    set ::uno::IsColorChange 1
  }
  ::uno::check_hasuno $nick
  set ::uno::IsDraw 0
  return 1
}

#
# Number card
#
proc ::uno::PlayUnoNumberCard {nick pickednum crd} {
  set CardOk 0
  set c1 [string range $crd 0 0]
  set c2 [string range $crd 1 1]
  set cip1 [string range $::uno::PlayCard 0 0]
  set cip2 [string range $::uno::PlayCard 1 1]
  if {$c2 == -1} {return 0}
  if {$c1 == $cip1} {set CardOk 1}
  if {($cip2 != "")} {
    if {$c2 == $cip2} {set CardOk 1}
  }
  if {$CardOk == 1} {
    incr ::uno::CardStats(played)
    ::uno::AddToDiscardPile $::uno::PlayCard
    ::uno::RemoveCardFromHand $nick $pickednum
    set ::uno::PlayCard $crd
    set Card [::uno::CardColor $crd]
    set NumberCardPlayer $::uno::ThisPlayer
    ::uno::NextPlayer
    if {[::uno::check_unowin $NumberCardPlayer $Card] > 0} {
      ::uno::showwin $NumberCardPlayer $Card
      ::uno::Win $NumberCardPlayer
      ::uno::Cycle
      return 1
    }
    ::uno::playcard $nick $Card $::uno::ThisPlayer
    ::uno::check_hasuno $NumberCardPlayer
    set Card [::uno::CardColorAll $::uno::ThisPlayer]
    ::uno::showcards $::uno::ThisPlayerIDX $Card
    set ::uno::IsDraw 0
    return 1
  }
  ::uno::ntc $nick [::msgcat::mc uno_invalidcard]
  return 0
}

#
# Attempt to find card in hand
#
proc ::uno::FindCard {nick pickednum crd IsRobot} {
  if {$::debug > 1} {::uno::log $::uno::Robot "UnoFindCard: [lindex $::uno::Hand($::uno::ThisPlayer) $pickednum"}
  # Wild Draw Four
  set FoundCard [::uno::PlayUnoWildDrawFourCard $nick $pickednum $crd $IsRobot]
  if {$FoundCard == 1} {return 4}
  # Wild
  set FoundCard [::uno::PlayUnoWildCard $nick $pickednum $crd $IsRobot]
  if {$FoundCard == 1} {return 5}
  # Draw Two
  set FoundCard [::uno::PlayUnoDrawTwoCard $nick $pickednum $crd]
  if {$FoundCard == 1} {return 3}
  # Skip
  set FoundCard [::uno::PlayUnoSkipCard $nick $pickednum $crd]
  if {$FoundCard == 1} {return 1}
  # Reverse
  set FoundCard [::uno::PlayUnoReverseCard $nick $pickednum $crd]
  if {$FoundCard == 1} {return 2}
  # Number card
  set FoundCard [::uno::PlayUnoNumberCard $nick $pickednum $crd]
  if {$FoundCard == 1} {return 6}
  return 0
}

#
# Play a card
#
proc ::uno::PlayCard {nick uhost hand chan arg} {
  if {($chan != $::uno::Chan)||($::uno::Mode != 2)||($nick != $::uno::ThisPlayer)} {return}
  ::uno::AutoSkipReset
  if {$::uno::IsColorChange == 1} {return}
  regsub -all \[`,.!{}\ ] $arg "" arg
  if {$arg == ""} {return}
  set pcard [string toupper [string range $arg 2 end]]
  set CardInPlayerHand 0
  set pcount 0
  if {$::debug==1} {
    puts "arg         : $arg"
    puts "Player hand : $::uno::Hand($nick)"
    puts "Asked card  : $pcard"
  }
  while {[lindex $::uno::Hand($nick) $pcount] != ""} {
    if {$pcard == [lindex $::uno::Hand($nick) $pcount]} {
      set pcardnum $pcount
      set CardInPlayerHand 1
      break
    }
    incr pcount
  }
  if {$CardInPlayerHand == 0} {
    ::uno::ntc $nick [::msgcat::mc uno_notinhand]
    return
  }
  set CardFound [::uno::FindCard $nick $pcardnum $pcard 0]
  switch $CardFound {
    0 {return}
    4 {return}
    5 {return}
    default {::uno::RobotRestart; return}
  }
}

#
# Robot Player
#
proc ::uno::RobotPlayer {} {
  # Check for a valid card in hand
  set CardOk 0
  set IsDraw 0
  set CardCount 0
  set cip1 [string range $::uno::PlayCard 0 0]
  set cip2 [string range $::uno::PlayCard 1 1]
  while {$CardCount < [llength $::uno::Hand($::uno::ThisPlayer)]} {
    set playcard [lindex $::uno::Hand($::uno::ThisPlayer) $CardCount]
    set c1 [string range $playcard 0 0]
    set c2 [string range $playcard 1 1]
    if {$::debug > 1} {::uno::log $::uno::Robot "Trying: $playcard"}
    if {($c1 == $cip1)||($c2 == $cip2)||($c1 == "W")} {
      set CardOk 1
      set pcard $playcard
      set pcardnum $CardCount
      break
    }
    incr CardCount
  }
  # Play the card if found
  if {$CardOk == 1} {
    set CardFound [::uno::FindCard $::uno::Robot $pcardnum $pcard 1]
    switch $CardFound {
      0 {}
      5 {return}
      6 {return}
      default {::uno::RobotRestart; return}
    }
  }
  # Bot draws a card
  ::uno::Shuffle 1
  set dcardnum [expr {int(rand() * [llength $::uno::Deck])}]
  set dcard [lindex $::uno::Deck $dcardnum]
  lappend ::uno::Hand($::uno::Robot) "$dcard"
  set ::uno::Deck [lreplace ${::uno::Deck} $dcardnum $dcardnum]
  ::uno::showwhodrew $::uno::Robot
  set CardOk 0
  set CardCount 0
  incr ::uno::CardStats(drawn)
  while {$CardCount < [llength $::uno::Hand($::uno::ThisPlayer)]} {
    set playcard [lindex $::uno::Hand($::uno::ThisPlayer) $CardCount]
    set c1 [string range $playcard 0 0]
    set c2 [string range $playcard 1 1]
    if {$::debug > 1} {::uno::log $::uno::Robot "DrawTry: $playcard"}
    if {($c1 == $cip1)||($c2 == $cip2)||($c1 == "W")} {
      set CardOk 1
      set pcard $playcard
      set pcardnum $CardCount
      break
    }
    incr CardCount
  }
  # Bot plays drawn card or passes turn
  if {$CardOk == 1} {
    set CardFound [::uno::FindCard $::uno::Robot $pcardnum $pcard 1]
    if {$CardFound == 1} {::uno::RobotRestart; return}
    switch $CardFound {
      0 {}
      5 {return}
      6 {return}
      default {::uno::RobotRestart; return}
    }
  } {
    incr ::uno::CardStats(passed)
    set ::uno::IsDraw 0
    ::uno::NextPlayer
    ::uno::playpass $::uno::Robot $::uno::ThisPlayer
    set Card [::uno::CardColorAll $::uno::ThisPlayer]
    ::uno::showcards $::uno::ThisPlayerIDX $Card
  }
  return
}

#
# Pause play
#
proc ::uno::Pause {nick uhost hand chan arg} {
  if {$chan != $::uno::Chan} {return}
  if {$::uno::On != 1} {return}
  if {$::uno::Mode != 2} {return}
  if {[is_oper $nick]} {
    if {$::uno::Paused == 0} {
      set ::uno::Paused 1
      ::uno::msg [::msgcat::mc uno_pauseon [::uno::ad] $nick]
    } {
      set ::uno::Paused 0
      ::uno::AutoSkipReset
      ::uno::msg [::msgcat::mc uno_pauseoff [::uno::ad] $nick]
    }
  }
}

#
# Remove user from play
#
proc ::uno::Remove {nick uhost hand chan arg} {
  if {$chan != $::uno::Chan} {return}
  if {$::uno::On == 0} {return}
  regsub -all \[`,.!{}] $arg "" arg
  # Allow Ops To Remove Another Player
  set UnoOpRemove 0
  if {[string length $arg] > 0} {
    if {[is_oper $nick]} {
      set UnoOpRemove 1
      set UnoOpNick $nick
      set nick $arg
    } {
      return
    }
  }
  set PlayerFound 0
  # Remove Player If Found - Put Cards Back To Bottom Of Deck
  set pcount 0
  while {[lindex $::uno::RoundRobin $pcount] != ""} {
    if {[string tolower [lindex $::uno::RoundRobin $pcount]] == [string tolower $nick]} {
      set PlayerFound 1
      set FoundIDX $pcount
      set nick [lindex $::uno::RoundRobin $pcount]
      break
    }
    incr pcount
  }
  if {$PlayerFound == 1} {
    if {$UnoOpRemove > 0} {
      ::uno::msg [::msgcat::mc uno_rembyop0 [::uno::nikclr $nick] $UnoOpNick]
    } {
      ::uno::ntc $nick [::msgcat::mc uno_rembyop1]
      ::uno::msg [::msgcat::mc uno_rembyop2 [::uno::nikclr $nick]]
    }
    # Player Was ColorPicker
    if {$::uno::IsColorChange == 1} {
      if {$nick == $::uno::ColorPicker} {
        # Make A Color Choice
        set cip [::uno::PickAColor]
        ::uno::msg [::msgcat::mc uno_shouldclrchg [::uno::nikclr $nick] $cip]
        set ::uno::IsColorChange 0
      } {
        if {$::debug==1} { puts "UnoRemove: IsColorChange Set but $nick not ColorPicker" }
      }
    }
    if {$nick == $::uno::ThisPlayer} {
      ::uno::NextPlayer
      if {$::uno::Players > 2} {
        ::uno::msg [::msgcat::mc uno_removenext [::uno::nikclr $nick] [::uno::nikclr $::uno::ThisPlayer]
      }
      ::uno::AutoSkipReset
    }
    set ::uno::Players [expr ($::uno::Players -1)]
    # Remove Player From Game And Put Cards Back In Deck
    if {$::uno::Players > 1} {
      set ::uno::RoundRobin [lreplace ${::uno::RoundRobin} $FoundIDX $FoundIDX]
      set ::uno::IDX [lreplace ${::uno::IDX} $FoundIDX $FoundIDX]
      lappend ::uno::DiscardPile "$::uno::Hand($nick)"
      unset ::uno::Hand($nick)
      unset ::uno::NickColor($nick)
    }
    set pcount 0
    while {[lindex $::uno::RoundRobin $pcount] != ""} {
      if {[lindex $::uno::RoundRobin $pcount] == $::uno::ThisPlayer} {
        set ::uno::ThisPlayerIDX $pcount
        break
      }
      incr pcount
    }
    if {$::uno::Players == 1} {
      ::uno::showwindefault $::uno::ThisPlayer
      ::uno::Win $::uno::ThisPlayer
      ::uno::Cycle
      return
    }
    ::uno::RobotRestart
  } {
    # Player not in current game
    return
  }
  if {$::uno::Players == 0} {
    ::uno::msg [::msgcat::mc uno_nowin [::uno::ad]]
    ::uno::Cycle
  }
  return
}

#
# Move to next player
#
proc ::uno::NextPlayer {} {
  incr ::uno::ThisPlayerIDX
  if {$::uno::ThisPlayerIDX >= [llength $::uno::RoundRobin]} {set ::uno::ThisPlayerIDX 0}
  set ::uno::ThisPlayer [lindex $::uno::RoundRobin $::uno::ThisPlayerIDX]
}

#
# Pick a random color for skipped/removed players
#
proc ::uno::PickAColor {} {
  set ucolors "r g b y"
  set pcol [string tolower [lindex $ucolors [expr {int(rand() * [llength $ucolors])}]]]
  switch $pcol {
    "r" {set ::uno::PlayCard "R"; return "\00300,04 [::msgcat::mc uno_red] \003"}
    "g" {set ::uno::PlayCard "G"; return "\00300,03 [::msgcat::mc uno_green] \003"}
    "b" {set ::uno::PlayCard "B"; return "\00300,12 [::msgcat::mc uno_blue] \003"}
    "y" {set ::uno::PlayCard "Y"; return "\00301,08 [::msgcat::mc uno_yellow] \003"}
  }
}

#
# Robot picks a color by checking hand for 1st color card
# found with matching color, else picks color at random
#
proc ::uno::BotPickAColor {} {
  set CardCount 0
  while {$CardCount < [llength $::uno::Hand($::uno::ThisPlayer)]} {
    set thiscolor [string range [lindex $::uno::Hand($::uno::ThisPlayer) $CardCount] 0 0]
    switch $thiscolor {
      "R" {set ::uno::PlayCard "R"; return "\00300,04 [::msgcat::mc uno_red] \003"}
      "G" {set ::uno::PlayCard "G"; return "\00300,03 [::msgcat::mc uno_green] \003"}
      "B" {set ::uno::PlayCard "B"; return "\00300,12 [::msgcat::mc uno_blue] \003"}
      "Y" {set ::uno::PlayCard "Y"; return "\00301,08 [::msgcat::mc uno_yellow] \003"}
    }
    incr CardCount
  }
  set ucolors "r g b y"
  set pcol [string tolower [lindex $ucolors [expr {int(rand() * [llength $ucolors])}]]]
  switch $pcol {
    "r" {set ::uno::PlayCard "R"; return "\00300,04 [::msgcat::mc uno_red] \003"}
    "g" {set ::uno::PlayCard "G"; return "\00300,03 [::msgcat::mc uno_green] \003"}
    "b" {set ::uno::PlayCard "B"; return "\00300,12 [::msgcat::mc uno_blue] \003"}
    "y" {set ::uno::PlayCard "Y"; return "\00301,08 [::msgcat::mc uno_yellow] \003"}
  }
}

#
# Set robot for next turn
#
proc ::uno::RobotRestart {} {
  if {$::uno::Mode != 2} {return}
  if {![::uno::isrobot $::uno::ThisPlayerIDX]} {return}
  set ::uno::BotTimer [after [expr {int($::uno::RobotRestartPeriod * 1000)}] ::uno::RobotPlayer]
}

#
# Reset autoskip timer
#
proc ::uno::AutoSkipReset {} {
  ### catch {after cancel $::uno::SkipTimer}
  if {$::uno::Mode == 2} {
    ### set ::uno::SkipTimer [after [expr {int($::uno::AutoSkipPeriod * 1000 * 60)}] ::uno::AutoSkip]
  }
}


#
# Read config file
#
proc ::uno::ReadCFG {} {
  if {[file exist $::uno::CFGFile]} {
    set f [open $::uno::CFGFile r]
    while {[gets $f s] != -1} {
      set kkey [string tolower [lindex [split $s "="] 0]]
      set kval [lindex [split $s "="] 1]
      switch $kkey {
        botname        {set ::uno::Robot $kval}
        channel        {set ::uno::Chan $kval}
        points         {set ::uno::PointsName $kval}
        scorefile      {set ::uno::ScoreFile $kval}
        stopafter      {set ::uno::StopAfter $kval}
        wilddrawtwos   {set ::uno::WildDrawTwos $kval}
        lastmonthcard1 {set ::uno::LastMonthCards(0) $kval}
        lastmonthcard2 {set ::uno::LastMonthCards(1) $kval}
        lastmonthcard3 {set ::uno::LastMonthCards(2) $kval}
        lastmonthwins1 {set ::uno::LastMonthGames(0) $kval}
        lastmonthwins2 {set ::uno::LastMonthGames(1) $kval}
        lastmonthwins3 {set ::uno::LastMonthGames(2) $kval}
        fast           {set ::uno::Fast $kval}
        high           {set ::uno::High $kval}
        played         {set ::uno::Played $kval}
        bonus          {set ::uno::Bonus $kval}
        recordhigh     {set ::uno::RecordHigh $kval}
        recordfast     {set ::uno::RecordFast $kval}
        recordcard     {set ::uno::RecordCard $kval}
        recordwins     {set ::uno::RecordWins $kval}
        recordplayed   {set ::uno::RecordPlayed $kval}
      }
    }
    close $f
    if {$::uno::StopAfter < 0} {set ::uno::StopAfter 0}
    if {$::uno::Bonus < 0} {set ::uno::Bonus 1000}
    if {($::uno::WildDrawTwos < 0)||($::uno::WildDrawTwos > 1)} {set ::uno::WildDrawTwos 0}
    return
  }
  ::uno::WriteCFG
  return
}

#
# Write config file
#
proc ::uno::WriteCFG {} {
  set f [open $::uno::CFGFile w]
  puts $f "# This file is automatically overwritten"
  puts $f "BotName=$::uno::Robot"
  puts $f "Channel=$::uno::Chan"
  puts $f "Points=$::uno::PointsName"
  puts $f "ScoreFile=$::uno::ScoreFile"
  puts $f "StopAfter=$::uno::StopAfter"
  puts $f "WildDrawTwos=$::uno::WildDrawTwos"
  puts $f "LastMonthCard1=$::uno::LastMonthCards(0)"
  puts $f "LastMonthCard2=$::uno::LastMonthCards(1)"
  puts $f "LastMonthCard3=$::uno::LastMonthCards(2)"
  puts $f "LastMonthWins1=$::uno::LastMonthGames(0)"
  puts $f "LastMonthWins2=$::uno::LastMonthGames(1)"
  puts $f "LastMonthWins3=$::uno::LastMonthGames(2)"
  puts $f "Fast=$::uno::Fast"
  puts $f "High=$::uno::High"
  puts $f "Played=$::uno::Played"
  puts $f "Bonus=$::uno::Bonus"
  puts $f "RecordHigh=$::uno::RecordHigh"
  puts $f "RecordFast=$::uno::RecordFast"
  puts $f "RecordCard=$::uno::RecordCard"
  puts $f "RecordWins=$::uno::RecordWins"
  puts $f "RecordPlayed=$::uno::RecordPlayed"
  close $f
  return
}

#
# Read score file
#
proc ::uno::ReadScores {} {
  if [info exists ::uno::gameswon] { unset ::uno::gameswon }
  if [info exists ::uno::ptswon] { unset ::uno::ptswon }
  if ![file exists $::uno::ScoreFile] {
    set f [open $::uno::ScoreFile w]
    puts $f "$::uno::Robot 0 0"
    close $f
  }
  set f [open $::uno::ScoreFile r]
  while {[gets $f s] != -1} {
    set ::uno::gameswon([lindex [split $s] 0]) [lindex $s 1]
    set ::uno::ptswon([lindex [split $s] 0]) [lindex $s 2]
  }
  close $f
  return
}

#
# Channel triggers
#

#
# Show current player order
#
proc ::uno::Order {nick uhost hand chan arg} {
  if {($chan != $::uno::Chan)||($::uno::Mode < 2)} {return}
  ::uno::msg [::msgcat::mc uno_order $::uno::Players $::uno::RoundRobin]
  return
}

#
# Show game running time
#
proc ::uno::Time {nick uhost hand chan arg} {
  if {($chan != $::uno::Chan)||($::uno::Mode != 2)} {return}
  ::uno::msg [::msgcat::mc uno_duration [::tools::duration [::uno::game_time]]
  return
}

#
# Show player what cards they hold
#
proc ::uno::ShowCards {nick uhost hand chan arg} {
  if {($chan != $::uno::Chan)||($::uno::Mode != 2)} {return}
  if [info exist ::uno::Hand($nick)] {
    set Card ""
    set ccnt 0
    while {[llength $::uno::Hand($nick)] != $ccnt} {
      set pcard [lindex $::uno::Hand($nick) $ccnt]
      append Card [::uno::CardColor $pcard]
      incr ccnt
    }
    if {![::uno::isrobot $::uno::ThisPlayerIDX]} {
      ::uno::ntc $nick [::msgcat::mc uno_inhand $Card]
    }
  }
  return
}

#
# Show current player
#
proc ::uno::Turn {nick uhost hand chan arg} {
  if {($chan != $::uno::Chan)||($::uno::Mode != 2)} {return}
  if {[llength $::uno::RoundRobin] < 1 } {return}
  ::uno::msg [::msgcat::mc uno_currpl $::uno::ThisPlayer]
  return
}

#
# Show current top card
#
proc ::uno::TopCard {nick uhost hand chan arg} {
  if {($chan != $::uno::Chan)||($::uno::Mode != 2)} {return}
  set pcard $::uno::PlayCard
  set Card [::uno::CardColor $pcard]
  ::uno::msg [::msgcat::mc uno_ingamecard $Card]
  return
}

#
# Show card stats
#
proc ::uno::CardStats {nick uhost hand chan arg} {
  if {($chan != $::uno::Chan)||($::uno::Mode != 2)} {return}
  ::uno::msg [::msgcat::mc uno_cardstats $::uno::CardStats(played) [format "%3.1f" [::uno::get_ratio $::uno::CardStats(passed) $::uno::CardStats(drawn)]] [expr $::uno::CardStats(skips) + $::uno::CardStats(revs)] $::uno::CardStats(draws) $::uno::CardStats(wilds)] 
  return
}

#
# Card count
#
proc ::uno::Count {nick uhost hand chan arg} {
  if {($chan != $::uno::Chan)||($::uno::Mode != 2)} {return}
  set ordcnt 0
  set crdcnt ""
  while {[lindex $::uno::RoundRobin $ordcnt] != ""} {
    append crdcnt "[::msgcat::mc uno_count [lindex $::uno::RoundRobin $ordcnt] [llength $::uno::Hand([lindex $::uno::RoundRobin $ordcnt])]] "
    incr ordcnt
  }
  ::uno::msg "$crdcnt"
  return
}

#
# Show player's score
#
proc ::uno::Won {nick uhost hand chan arg} {
  regsub -all \[`,.!] $arg "" arg
  if {[string length $arg] == 0} {set arg $nick}
  set scorer [string tolower $arg]
  set pflag 0
  set f [open $::uno::ScoreFile r]
  while {[gets $f sc] != -1} {
    set cnick [string tolower [lindex [split $sc] 0]]
    if {$cnick == $scorer} {
      set pmsg [::msgcat::mc uno_won [lindex [split $sc] 0] [lindex $sc 2] $::uno::PointsName [lindex $sc 1]]
      set pflag 1
    }
  }
  close $f
  if {$pflag == 0} {
    set pmsg [::msgcat::mc uno_wonnoscore $arg]
  }
  ::uno::msg "$pmsg"
  return
}

#
# Display current top10
#
proc ::uno::TopTen {nick uhost hand chan arg} {
  if {$chan != $::uno::Chan} {return}
  ::uno::Top10 1
  return
}
proc ::uno::TopTenWon {nick uhost hand chan arg} {
  if {$chan != $::uno::Chan} {return}
  ::uno::Top10 0
  return
}

#
# Display last month's top3
#
proc ::uno::TopThreeLast {nick uhost hand chan arg} {
  if {$chan != $::uno::Chan} {return}
  ::uno::LastMonthTop3 $nick $uhost $hand $chan 0
  ::uno::msg " "
  ::uno::LastMonthTop3 $nick $uhost $hand $chan 1
  return
}

#
# Display month fastest game
#
proc ::uno::TopFast {nick uhost hand chan arg} {
  if {$chan != $::uno::Chan} {return}
  ::uno::msg [::msgcat::mc uno_topfast [lindex [split $::uno::Fast] 0] [::tools::duration [lindex $::uno::Fast 1]]]
  return
}

#
# Display month high score
#
proc ::uno::HighScore {nick uhost hand chan arg} {
  if {$chan != $::uno::Chan} {return}
  ::uno::msg [::msgcat::mc uno_highscore [lindex [split $::uno::High] 0] [lindex $::uno::High 1] $::uno::PointsName]
  return
}

#
# Display month most cards played
#
proc ::uno::Played {nick uhost hand chan arg} {
  if {$chan != $::uno::Chan} {return}
  ::uno::msg [::msgcat::mc uno_played [lindex [split $::uno::Played] 0] [lindex $::uno::Played 1]]
  return
}

#
# Show all-time records
#
proc ::uno::Records {nick uhost hand chan arg} {
  if {$chan != $::uno::Chan} {return}
  ::uno::msg [::msgcat::mc uno_records $::uno::RecordCard $::uno::RecordWins [lindex $::uno::RecordFast 0] [::tools::duration [lindex $::uno::RecordFast 1]] $::uno::RecordHigh $::uno::RecordPlayed]
  return
}

#
# Display month top10
#
proc ::uno::Top10 {mode} {
  if {($mode < 0)||($mode > 1)} {set mode 0}
  switch $mode {
    0 {set winners [::msgcat::mc uno_topten0]}
    1 {set winners [::msgcat::mc uno_topten1]}
  }
  if ![file exists $::uno::ScoreFile] {
    set f [open $::uno::ScoreFile w]
    puts $f "$::uno::Robot 0 0"
    ::uno::msg [::msgcat::mc uno_emptyscorefile]
    close $f
    return
  }
  if [info exists ::uno::unsortedscores] {unset ::uno::unsortedscores}
  if [info exists top10] {unset top10}
  set f [open $::uno::ScoreFile r]
  while {[gets $f s] != -1} {
    switch $mode {
      0 {set ::uno::unsortedscores([lindex [split $s] 0]) [lindex $s 1]}
      1 {set ::uno::unsortedscores([lindex [split $s] 0]) [lindex $s 2]}
    }
  }
  close $f
  for {set s 0} {$s < 10} {incr s} {
    set top10($s) "[::msgcat::mc uno_nobody] 0"
  }
  set s 0
  foreach n [lsort -decreasing -command ::uno::SortScores [array names ::uno::unsortedscores]] {
    set top10($s) "$n $::uno::unsortedscores($n)"
    incr s
  }
  for {set s 0} {$s < 10} {incr s} {
    if {[lindex $top10($s) 1] > 0} {
      append winners "\00300,06 #[expr $s +1] \00300,10 [lindex [split $top10($s)] 0] [lindex $top10($s) 1] "
    } {
      append winners "\00300,06 #[expr $s +1] \00300,10 [::msgcat::mc uno_nobody] 0 "
    }
  }
  ::uno::msg "$winners"
  return
}

#
# Last month's top3
#
proc ::uno::LastMonthTop3 {nick uhost hand chan arg} {
  if {$chan != $::uno::Chan} {return}
  set UnoTop3 " "
  if {$arg == 0} {
    if [info exists ::uno::LastMonthCards] {
      set UnoTop3 "[::msgcat::mc uno_top3cards $::uno::PointsName] "
      for { set s 0} { $s < 3 } { incr s} {
        append UnoTop3 "\00300,06 #[expr $s +1] \00300,10 $::uno::LastMonthCards($s) "
      }
    }
  } {
    if [info exists ::uno::LastMonthGames] {
      set UnoTop3 "[::msgcat::mc uno_top3games] "
      for { set s 0} { $s < 3 } { incr s} {
        append UnoTop3 "\00300,06 #[expr $s +1] \00300,10 $::uno::LastMonthGames($s) "
      }
    }
  }
  ::uno::msg "$UnoTop3"
}

#
# Show game help
#
proc ::uno::Cmds {nick uhost hand chan arg} {
  if {$::debug==1} {
    puts "UNO : !unocmds par $nick."
    ::irc::send ":$::irc::nick [tok PRIVMSG] $::irc::adminchan :\00304UNO :\017 !unocmds par \00302$nick\017."
  }
  ::uno::ntc $nick [::msgcat::mc uno_helpcmd]
  ::uno::ntc $nick [::msgcat::mc uno_helpstats]
  ::uno::ntc $nick [::msgcat::mc uno_helpcards]
  ::uno::ntc $nick [::msgcat::mc uno_helpgame]
  return
}

#
# Uno version
#
proc ::uno::Version {nick uhost hand chan arg} {
  ::uno::msg [::msgcat::mc uno_version [::uno::ad] $::uno::Version]
  return
}

#
# Clear top10 and write monthly scores
#
proc ::uno::NewMonth {min hour day month year} {
  set lmonth [::uno::LastMonthName $month]
  ::uno::msg [::msgcat::mc uno_erasemonth [::uno::ad]]
  set UnoMonthFileName "$::uno::ScoreFile.$lmonth"
  # Read Current Scores
  ::uno::ReadScores
  # Write To Old Month File
  if ![file exists $UnoMonthFileName] {
    set f [open $UnoMonthFileName w]
     foreach n [array names ::uno::gameswon] {
       puts $f "$n $::uno::gameswon($n) $::uno::ptswon($n)"
     }
    close $f
  }
  # Find Top 3 Card Holders and Game Winners
  set mode 0
  while {$mode < 2} {
    if [info exists ::uno::unsortedscores] {unset ::uno::unsortedscores}
    if [info exists top10] {unset top10}
    set f [open $::uno::ScoreFile r]
    while {[gets $f s] != -1} {
      switch $mode {
        0 {set ::uno::unsortedscores([lindex [split $s] 0]) [lindex $s 1]}
        1 {set ::uno::unsortedscores([lindex [split $s] 0]) [lindex $s 2]}
      }
    }
    close $f
    set s 0
    foreach n [lsort -decreasing -command ::uno::SortScores [array names ::uno::unsortedscores]] {
      set top10($s) "$n $::uno::unsortedscores($n)"
      incr s
    }
    for {set s 0} {$s < 3} {incr s} {
      if {[lindex $top10($s) 1] > 0} {
       switch $mode {
          0 {set ::uno::LastMonthGames($s) "[lindex [split $top10($s)] 0] [lindex $top10($s) 1]"}
          1 {set ::uno::LastMonthCards($s) "[lindex [split $top10($s)] 0] [lindex $top10($s) 1]"}
        }
      } {
        switch $mode {
          0 {set ::uno::LastMonthGames($s) "[::msgcat::mc uno_nobody] 0"}
          1 {set ::uno::LastMonthCards($s) "[::msgcat::mc uno_nobody] 0"}
        }
      }
    }
    incr mode
  }
  # Update records
  if {[lindex $::uno::Fast 1] < [lindex $::uno::RecordFast 1]} {set ::uno::RecordFast $::uno::Fast}
  if {[lindex $::uno::High 1] > [lindex $::uno::RecordHigh 1]} {set ::uno::RecordHigh $::uno::High}
  if {[lindex $::uno::Played 1] > [lindex $unoRecordPlayed 1]} {set ::uno::RecordPlayed $::uno::Played}
  if {[lindex $::uno::LastMonthCards(0) 1] > [lindex $::uno::RecordCard 1]} {set ::uno::RecordCard $::uno::LastMonthCards(0)}
  if {[lindex $::uno::LastMonthGames(0) 1] > [lindex $::uno::RecordWins 1]} {set ::uno::RecordWins $::uno::LastMonthGames(0)}
  # Wipe last months records
  set ::uno::Fast   "$::uno::Robot 60"
  set ::uno::High   "$::uno::Robot 100"
  set ::uno::Played "$::uno::Robot 100"
  # Save Top3 And Records To Config File
  ::uno::WriteCFG
  # Wipe This Months Score File
  set f [open $::uno::ScoreFile w]
  puts $f "$::uno::Robot 0 0"
  close $f
  if {$::debug==1} { puts "Month scores erased." }
  return
}

#
# Update score of winning player
#
proc ::uno::UpdateScore {winner cardtotals} {
  ::uno::ReadScores
  if {[info exists ::uno::gameswon($winner)]} {
    incr ::uno::gameswon($winner)
  } {
    set ::uno::gameswon($winner) 1
  }
  if {[info exists ::uno::ptswon($winner)]} {
    incr ::uno::ptswon($winner) $cardtotals
  } {
    set ::uno::ptswon($winner) $cardtotals
  }
  set f [open $::uno::ScoreFile w]
  foreach n [array names ::uno::gameswon] {
    puts $f "$n $::uno::gameswon($n) $::uno::ptswon($n)"
  }
  close $f
  return
}

#
# Display winner and game statistics
#
proc ::uno::Win {winner} {
  set cardtotals 0
  set ::uno::Mode 3
  set ::uno::ThisPlayerIDX 0
  set needCFGWrite 0
  set UnoTime [::uno::game_time]
  ::uno::msg [::msgcat::mc uno_end0]
  # Total up all player's cards
  while {$::uno::ThisPlayerIDX != [llength $::uno::RoundRobin]} {
    set Card ""
    set ::uno::ThisPlayer [lindex $::uno::RoundRobin $::uno::ThisPlayerIDX]
    if {$::uno::ThisPlayer != $winner} {
      set ccount 0
      while {[lindex $::uno::Hand($::uno::ThisPlayer) $ccount] != ""} {
        set cardtotal [lindex $::uno::Hand($::uno::ThisPlayer) $ccount]
        set c1 [string range $cardtotal 0 0]
        set c2 [string range $cardtotal 1 1]
        set cardtotal 0
        if {$c1 == "W"} {
          set cardtotal 50
        } {
          switch $c2 {
            "S" {set cardtotal 20}
            "R" {set cardtotal 20}
            "D" {set cardtotal 20}
            default {set cardtotal $c2}
          }
        }
        set cardtotals [expr $cardtotals + $cardtotal]
        incr ccount
      }
      set Card [::uno::CardColorAll $::uno::ThisPlayer]
      ::uno::msg "[::uno::strpad [::uno::nikclr $::uno::ThisPlayer] 12] $Card"
    }
    incr ::uno::ThisPlayerIDX
  }
  # Check high score record
  set HighScore [lindex $::uno::High 1]
  if {$cardtotals > $HighScore} {
    ::uno::msg [::msgcat::mc uno_endhighscore $winner $::uno::Bonus $::uno::PointsName]
    set ::uno::High "$winner $cardtotals"
    incr cardtotals $::uno::Bonus
    set needCFGWrite 1
  }
  # Check played cards record
  set HighPlayed [lindex $::uno::Played 1]
  if {$::uno::CardStats(played) > $HighPlayed} {
    ::uno::msg [::msgcat::mc uno_endplayed $winner $::uno::Bonus $::uno::PointsName]
    set ::uno::Played "$winner $::uno::CardStats(played)"
    incr cardtotals $::uno::Bonus
    set needCFGWrite 1
  }
  # Check fast game record
  set FastRecord [lindex $::uno::Fast 1]
  if {$UnoTime < $FastRecord} {
    ::uno::msg [::msgcat::mc uno_endtime $winner $::uno::Bonus $::uno::PointsName]
    incr cardtotals $::uno::Bonus
    set ::uno::Fast "$winner $UnoTime"
    set needCFGWrite 1
  }
  # Winner
  ::uno::msg [::msgcat::mc uno_endwinner $winner $cardtotals $::uno::PointsName [::tools::duration $UnoTime]]
  # Card stats
  ::uno::msg [::msgcat::mc uno_cardstats $::uno::CardStats(played) [format "%3.1f" [get_ratio $::uno::CardStats(passed) $::uno::CardStats(drawn)]] [expr $::uno::CardStats(skips) + $::uno::CardStats(revs)] $::uno::CardStats(draws) $::uno::CardStats(wilds)]
  ::uno::msg [::msgcat::mc uno_endnextgame [::uno::ad] $::uno::CycleTime]
  # Write scores
  ::uno::UpdateScore $winner $cardtotals
  # Write records
  if {$needCFGWrite > 0} {::uno::WriteCFG}
  return
}

#
# Re-Shuffle deck
#
proc ::uno::Shuffle {len} {
  if {[llength $::uno::Deck] >= $len} { return }
  ::uno::msg [::msgcat::mc uno_shuffle [::uno::ad]]
  lappend ::uno::DiscardPile "$::uno::Deck"
  set ::uno::Deck ""
  set NewDeckSize [llength $::uno::DiscardPile]
  while {[llength $::uno::Deck] != $NewDeckSize} {
    set pcardnum [expr {int(rand() * [llength $::uno::DiscardPile])}]
    set pcard [lindex $::uno::DiscardPile $pcardnum]
    lappend ::uno::Deck "$pcard"
    set ::uno::DiscardPile [lreplace ${::uno::DiscardPile} $pcardnum $pcardnum]
  }
  return
}

#
# Score advertiser
#
proc ::uno::ScoreAdvertise {} {
  ::uno::msg " "
  switch $::uno::AdNumber {
    0 {::uno::Top10 0}
    1 {::uno::LastMonthTop3 $::uno::Robot none none $::uno::Chan 0}
    2 {::uno::Records $::uno::Robot none none $::uno::Chan ""}
    3 {::uno::Top10 1}
    4 {::uno::Played $::uno::Robot none none $::uno::Chan ""}
    5 {::uno::HighScore $::uno::Robot none none $::uno::Chan ""}
    6 {::uno::TopFast $::uno::Robot none none $::uno::Chan ""}
  }
  incr ::uno::AdNumber
  if {$::uno::AdNumber > 6} {set ::uno::AdNumber 0}
  return
}

#
# Color all cards in hand
#
proc ::uno::CardColorAll {cplayer} {
  set pCard ""
  set ccount 0
  while {[llength $::uno::Hand($cplayer)] != $ccount} {
    append pCard [::uno::CardColor [lindex $::uno::Hand($cplayer) $ccount]]
    incr ccount
  }
  return $pCard
}

#
# Color a single card
#
proc ::uno::CardColor {pcard} {
  set cCard ""
  set c2 [string range $pcard 1 1]
  switch [string range $pcard 0 0] {
    "W" {
      if {$c2 == "D"} {
        append cCard "[wildf]"
      } {
        append cCard "[wild]"
      }
      return $cCard
    }
    "Y" {append cCard " \00301,08 [::msgcat::mc uno_yellow] "}
    "R" {append cCard " \00300,04 [::msgcat::mc uno_red] "}
    "G" {append cCard " \00300,03 [::msgcat::mc uno_green] "}
    "B" {append cCard " \00300,12 [::msgcat::mc uno_blue] "}
  }
  switch $c2 {
    "S" {append cCard "\002[::msgcat::mc uno_skip]\002 \003 "}
    "R" {append cCard "\002[::msgcat::mc uno_reverse]\002 \003 "}
    "D" {append cCard "\002[::msgcat::mc uno_drawtwo]\002 \003 "}
    default {append cCard "$c2 \003 "}
  }
  return $cCard
}

#
# Check if player has Uno
#
proc ::uno::check_hasuno {cplayer} {
  if {[llength $::uno::Hand($cplayer)] > 1} {return}
  ::uno::hasuno $cplayer
  return
}

#
# Check for winner
#
proc ::uno::check_unowin {cplayer ccard} {
  if {[llength $::uno::Hand($cplayer)] > 0} {return 0}
  return 1
}

#
# Show player what cards they have
#
proc ::uno::showcards {idx pcards} {
  if {[::uno::isrobot $idx]} {return}
  ::uno::ntc [lindex $::uno::IDX $idx] "En main : $pcards"
}

#
# Check if this is the robot player
#
proc ::uno::isrobot {cplayerIDX} {
  if {[string range [lindex $::uno::RoundRobin $cplayerIDX] 0 $::uno::MaxNickLen] != $::uno::Robot} {return 0}
  return 1
}

# Show played card
proc ::uno::playcard {who crd nplayer} {
  if {$::debug==1} {
    puts "$who"
    puts "$crd"
    puts "$nplayer"
    puts "-[::uno::nikclr $who]-"
    puts "-[::uno::nikclr $nplayer]-"
    puts "::uno::msg [::msgcat::mc uno_playcard [::uno::nikclr $who] $crd [::uno::nikclr $nplayer]]"
  }
  ::uno::msg [::msgcat::mc uno_playcard [::uno::nikclr $who] "$crd" [::uno::nikclr $nplayer]]
}
# Show played draw card
proc ::uno::playdraw {who crd dplayer nplayer} { ::uno::msg [::msgcat::mc uno_playdraw [::uno::nikclr $who] $crd [::uno::nikclr $dplayer] [::uno::nikclr $nplayer]] }
# Show played wildcard
proc ::uno::playwild {who chooser} { ::uno::msg [::msgcat::mc uno_playwild [::uno::nikclr $who] [::uno::wild] [::uno::nikclr $chooser]] }
# Show played wild draw four
proc ::uno::playwildfour {who skipper chooser} { ::uno::msg [::msgcat::mc uno_playwildfour [::uno::nikclr $who] [::uno::wildf] [::uno::nikclr $skipper] [::uno::nikclr $chooser]] }
# Show played skip card
proc ::uno::playskip {who crd skipper nplayer} { ::uno::msg [::msgcat::mc uno_playskip [::uno::nikclr $who] $crd [::uno::nikclr $skipper] [::uno::nikclr $nplayer]] }
proc ::uno::showwhodrew {who} { ::uno::msg [::msgcat::mc uno_showwhodrew [::uno::nikclr $who]] }
proc ::uno::playpass {who nplayer} { ::uno::msg [::msgcat::mc uno_playpass [::uno::nikclr $who] [::uno::nikclr $nplayer]] }
# Show played wildcard
proc ::uno::botplaywild {who chooser ncolr nplayer} { ::uno::msg [::msgcat::mc uno_botplaywild [::uno::nikclr $who] [::uno::wild] $ncolr [::uno::nikclr $nplayer]] }
# Show played wild draw four
proc ::uno::botplaywildfour {who skipper chooser choice nplayer} { ::uno::msg [::msgcat::mc uno_botplaywildfour [::uno::nikclr $who] [::uno::wildf] [::uno::nikclr $skipper] [::uno::nikclr $chooser] $choice [::uno::nikclr $nplayer]] }
# Show a player what they drew
proc ::uno::showdraw {idx crd} {
  if {[::uno::isrobot $idx]} {return}
  ::uno::ntc [lindex $::uno::IDX $idx] [::msgcat::mc uno_draw $crd]
}

# Show Win
proc ::uno::showwin {who crd} { ::uno::msg [::msgcat::mc uno_showwin [::uno::nikclr $who] $crd [::uno::ad]] }
# Show Win by default
proc ::uno::showwindefault {who} { ::uno::msg [::msgcat::mc uno_showwindefault [::uno::nikclr $who] [::uno::ad]] }
# Player Has Uno
proc ::uno::hasuno {who} { ::irc::send ":$::uno::nick [tok PRIVMSG] $::uno::Chan :\001ACTION [::msgcat::mc uno_hasuno [::uno::nikclr $who]]\001" }


#
# Utility Functions
#

# Check if a timer exists
proc ::uno::timerexists {cmd} {
  set ret [after info $cmd]
  puts ret 
  if {[string match -nocase -- $cmd [info procs [lindex $ret 0]]]} { return 1 }
  return
}

# Sort Scores
proc ::uno::SortScores {s1 s2} {
  if {$::uno::unsortedscores($s1) >  $::uno::unsortedscores($s2)} {return 1}
  if {$::uno::unsortedscores($s1) <  $::uno::unsortedscores($s2)} {return -1}
  if {$::uno::unsortedscores($s1) == $::uno::unsortedscores($s2)} {return 0}
}

# Calculate Game Running Time
proc ::uno::game_time {} {
  set ::uno::CurrentTime [::tools::unixtime]
  set gt [expr ($::uno::CurrentTime - $::uno::StartTime)]
  return $gt
}

# Colorize Nickname
proc ::uno::nikclr {nick} {
  return "\003$::uno::NickColor($nick)$nick"
}
proc ::uno::colornick {pnum} {
  set c [lindex $::uno::NickColour [expr $pnum-1]]
  set nik [format "%02d" $c]
  return $nik
}

# Ratio Of Two Numbers
proc ::uno::get_ratio {num den} {
  set n 0.0
  set d 0.0
  set n [expr $n +$num]
  set d [expr $d +$den]
  if {$d == 0} {return 0}
  set ratio [expr (($n /$d) *100.0)]
  return $ratio
}

# Name Of Last Month
proc ::uno::LastMonthName {month} {
  switch $month {
    00 {return "Dec"}
    01 {return "Jan"}
    02 {return "Feb"}
    03 {return "Mar"}
    04 {return "Apr"}
    05 {return "May"}
    06 {return "Jun"}
    07 {return "Jul"}
    08 {return "Aug"}
    09 {return "Sep"}
    10 {return "Oct"}
    11 {return "Nov"}
    12 {return "Dec"}
    default {return "???"}
  }
}

# String Pad
proc ::uno::strpad {str len} {
  set slen [string length $str]
  if {$slen > $len} {return $str}
  while {$slen < $len} {
    append str " "
    incr slen
  }
  return $str
}

# Uno!
proc ::uno::ad {} { return "\002\00303U\00312N\00313O\00308!" }
# Wild Card
proc ::uno::wild {} { return " \00301,08 \002W\00300,03I\00300,04L\00300,12D\002 \003 " }
# Wild Draw Four Card
proc ::uno::wildf {} { return " \00301,08 \002W\00300,03I\00300,04L\00300,12D \00301,08D\00300,03r\00300,04a\00300,12w \00301,08F\00300,03o\00300,04u\00300,12r\002 \003 " }

#
# Channel And DCC Messages
#
proc ::uno::msg {what} {
  ::irc::send ":$::uno::nick [tok PRIVMSG] $::uno::chan :$what"
}
proc ::uno::ntc {who what} {
  ::irc::send ":$::uno::nick $::uno::NTC $who :$what"
}
proc ::uno::log {who what} {
  puts "\[$who\] $what"
}

::uno::ReadCFG
::uno::ReadScores

proc ::uno::AutoSkip {} { return }

###
### Original bot
###
return 0
###
### MARK
###
#bind time - "00 00 01 * *" UnoNewMonth

#
# Autoskip inactive players
#
proc UnoAutoSkip {} {
  global UnoMode ThisPlayer ThisPlayerIDX RoundRobin AutoSkipPeriod IsColorChange ColorPicker
  global UnoIDX UnoPlayers UnoDeck UnoHand UnoChan UnoSkipTimer Debug NickColor UnoPaused
  global mysock
  if {$UnoMode != 2} {return}
  if {$UnoPaused != 0} {return}
  if {[uno_isrobot $::uno::ThisPlayerIDX]} {return}
  set Idler $::uno::ThisPlayer
  set IdlerIDX $::uno::ThisPlayerIDX
  if {[unotimerexists UnoSkipTimer] != ""} {
    if {$mysock(debug)==1} { puts "AutoSkip Timer already exists." }
    return
  }
  set InChannel 0
  set uclist [chanlist $UnoChan]
  set pcount 0
  while {[lindex $uclist $pcount] != ""} {
    if {[lindex $uclist $pcount] == $Idler} {
      set InChannel 1
      break
    }
    incr pcount
  }
  if {$InChannel == 0} {
    ::uno::msg [::msgcat::mc uno_plhasleft [::uno::nikclr $Idler]]
    if {$IsColorChange == 1} {
      if {$Idler == $ColorPicker} {
        # Make A Color Choice
        set cip [UnoPickAColor]
        ::uno::msg [::msgcat::mc uno_shouldclrchg $Idler $cip]
        set IsColorChange 0
      } {
        if {$mysock(debug)==1} { puts "UnoAutoRemove: IsColorChange set but $Idler not ColorPicker" }
      }
    }
    UnoNextPlayer
    ::uno::msg [::msgcat::mc uno_removenext [::uno::nikclr $Idler] [::uno::nikclr $ThisPlayer]]
    if {![uno_isrobot $ThisPlayerIDX]} {
      set Card [CardColorAll $ThisPlayer]
      showcards $ThisPlayerIDX $Card
    }
    set UnoPlayers [expr ($UnoPlayers -1)]
    # Remove Player From Game And Put Cards Back In Deck
    if {$UnoPlayers > 1} {
      set RoundRobin [lreplace ${RoundRobin} $IdlerIDX $IdlerIDX]
      set UnoIDX [lreplace ${UnoIDX} $IdlerIDX $IdlerIDX]
      lappend UnoDeck "$UnoHand($Idler)"
      unset UnoHand($Idler)
      unset NickColor($Idler)
    }
    switch $UnoPlayers {
      1 {
         showwindefault $ThisPlayer
         UnoWin $ThisPlayer
         UnoCycle
       }
     0 {
         ::uno::msg [::msgcat::mc uno_nowin [::uno::ad]]
         UnoCycle
       }
     default {
         if {![uno_isrobot $ThisPlayerIDX]} {
           UnoAutoSkipReset
           UnoRobotRestart
         }
       }
    }
    return
  }
  if {$mysock(debug)==1} { puts "AutoSkip Player: $Idler" }
  ::uno::msg [::msgcat::mc uno_idleplayer [::uno::nikclr $Idler] $AutoSkipPeriod]
  # Player Was ColorPicker
  if {$IsColorChange == 1} {
    if {$Idler == $ColorPicker} {
      # Make A Color Choice
      set cip [UnoPickAColor]
      ::uno::msg [::msgcat::mc uno_shouldclrchg [::uno::nikclr $Idler] $cip]
      set IsColorChange 0
    } {
      if {$mysock(debug)==1} { puts "UnoAutoRemove: IsColorChange set but $Idler not ColorPicker" }
    }
  }
  UnoNextPlayer
  ::uno::msg [::msgcat::mc uno_removenext [::uno::nikclr $Idler] [::uno::nikclr $ThisPlayer]]
  if {![uno_isrobot $ThisPlayerIDX]} {
    set Card [CardColorAll $ThisPlayer]
    showcards $ThisPlayerIDX $Card
  } {
    UnoRobotRestart
  }
  UnoAutoSkipReset
  return
}

# vim: set fenc=utf-8 sw=2 sts=2 ts=2 et filetype=tcl
