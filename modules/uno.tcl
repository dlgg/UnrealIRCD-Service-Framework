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
  variable nick       "UNO"
  variable username   "uno"
  variable hostname   "uno.$::irc::hostname"
  variable realname   "Bot de jeu UNO"
  variable chan       "#UNO"

# Game variables
  variable Chan         $::uno::chan
  variable Robot        $::uno::nick
  variable PointsName   "Points"
  variable StopAfter    5
  variable Bonus        1000
  variable WildDrawTwos 1
  variable CFGFile      "games/uno.cfg"
  variable ScoreFile    "games/UnoScores"
  variable MaxNickLen   32
  variable MaxPlayers   8
  variable NTC          "NOTICE"

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
  variable LastMonthCards(0) "Personne 0"
  variable LastMonthCards(1) "Personne 0"
  variable LastMonthCards(2) "Personne 0"
  variable LastMonthGames(0) "Personne 0"
  variable LastMonthGames(1) "Personne 0"
  variable LastMonthGames(2) "Personne 0"
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
  variable CardStats(played) 0
  variable CardStats(passed) 0
  variable CardStats(drawn) 0
  variable CardStats(wilds) 0
  variable CardStats(draws) 0
  variable CardStats(skips) 0
  variable CardStats(revs) 0
  
  # Timers
  variable StartTimer ""
  variable SkipTimer ""
  variable CycleTimer ""
  variable BotTimer ""
  
  # Grace periods and timeouts
  # AutoSkip period can be raised but not lower than 2
  variable AutoSkipPeriod 2
  variable StartGracePeriod 30
  variable RobotRestartPeriod 1
  variable CycleTime 30
  
  # Nick colours
  variable NickColour "06 13 03 07 12 10 04 11 09 08"
  
  # Debugging info
  variable Debug $::debug
  variable Version "0.96.74.3"

  # Don't modify this
  ::irc::hook_register privmsg-[string tolower $::uno::chan] "::uno::control_pub"
  ::irc::hook_register privmsg-[string tolower $::uno::nick] "::uno::control_priv"
  ::irc::hook_register join-[string tolower $::uno::chan]    "::uno::control_join"
}

proc ::uno::control_join { nick } { ::irc::send ":$::uno::nick NOTICE $nick :[::msgcat::mc uno_welcome [::uno::ad]]" }
proc ::uno::control_priv { nick text } { if {$::debug==1} { ::irc::send ":$::uno::nick PRIVMSG $::uno::chan :\002PRIV\002 $nick > [join $text]" } }

proc ::uno::control_pub { nick text } {
  # nick uhost hand chan arg
  #if {$::debug==1} { ::irc::send ":$::uno::nick PRIVMSG $::uno::chan :\002PUB \002 $nick > [join $text]" }
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
    if {$chan != $::uno::Chan} { ::irc::send ":$::uno::nick PRIVMSG $chan :[::msgcat::mc uno_startalready0 [::uno::ad]]" }
    if {$chan == $::uno::Chan} { ::irc::send ":$::uno::nick PRIVMSG $chan :[::msgcat::mc uno_startalready1 [::uno::ad]]" }
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
  while {[llength $::uno::deck] != 108} {
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

    while {[llength $UnoHand($UnoRobot)] != 7} {
      set pcardnum [expr {int(rand() * [llength $UnoDeck])}]
      set pcard [lindex $UnoDeck $pcardnum]
      set UnoDeck [lreplace ${UnoDeck} $pcardnum $pcardnum]
      lappend UnoHand($UnoRobot) "$pcard"
    }
    if {$Debug > 1} { unolog $UnoRobot $UnoHand($UnoRobot) }
  }
  ::uno::msg [::msgcat::mc uno_welcome0 [::uno::ad]]
  ::uno::msg [::msgcat::mc uno_welcome1 $UnoPlayers $RoundRobin]
  set UnoMode 2
  set ThisPlayer [lindex $RoundRobin 0]

  # Draw Card From Deck - First Top Card
  set DiscardPile ""
  set pcardnum [expr {int(rand() * [llength $UnoDeck])}]
  set pcard [lindex $UnoDeck $pcardnum]

  # Play Doesnt Start With A Wild Card
  while {[string range $pcard 0 0] == "W"} {
    set pcardnum [expr {int(rand() * [llength $UnoDeck])}]
    set pcard [lindex $UnoDeck $pcardnum]
  }

  set PlayCard $pcard
  set UnoDeck [lreplace ${UnoDeck} $pcardnum $pcardnum]
  set Card [CardColor $pcard]
  ::uno::msg [::msgcat::mc uno_start [::uno::nikclr $ThisPlayer] $Card]
  set Card [CardColorAll $ThisPlayer]
  showcards $ThisPlayerIDX $Card
  set UnoStartTime [unixtime]

  # Start Auto-Skip Timer
  ### set UnoSkipTimer [after [expr {int($AutoSkipPeriod*1000*60)}] UnoAutoSkip]
  set UnPlayedRounds 0
  return
}

#
# Stop a game
#
proc UnoStop {nick uhost hand chan arg} {
  global Debug UnoChan UnoOn UnoPaused UnPlayedRounds UnoStartTimer UnoSkipTimer UnoCycleTimer
  global mysock
  if {$chan != $UnoChan} {return}
  catch {after cancel $UnoStartTimer}
  ### catch {after cancel $UnoSkipTimer}
  catch {after cancel $UnoCycleTimer}
  ::uno::msg [::msgcat::mc uno_stop0 [::uno::ad] $nick]
  if {$mysock(debug)==1} { puts [::msgcat::mc uno_stop1 $nick $chan] }
  set UnoOn 0
  set UnoPaused 0
  set UnPlayedRounds 0
  UnoReset
  return
}

#
# Cycle a new game
#
proc UnoCycle {} {
  global UnoOn UnoMode UnoCycleTime UnoCycleTimer UnoSkipTimer
  if {$UnoOn == 0} {return}
  set UnoMode 4
  ### catch {after cancel $UnoSkipTimer}
  set AdTime [expr $UnoCycleTime /2]
  set UnoAdTimer [after [expr {int($AdTime*1000)}] UnoScoreAdvertise]
  set UnoCycleTimer [after [expr {int($UnoCycleTime*1000)}] UnoNext]
  return
}

#
# Add a player
#
proc JoinUno {nick uhost hand chan arg} {
  global Debug UnoIDX UnoMode UnoPlayers RoundRobin UnoDeck UnoHand UnoChan NickColor UnoMaxPlayers
  global mysock
  if {($chan != $UnoChan)||($UnoMode < 1)||($UnoMode > 2)} {return}
  if {[llength $RoundRobin] == $UnoMaxPlayers} {
    unontc $nick [::msgcat::mc uno_maxplayers $nick]
    return
  }
  set pcount 0
  while {[lindex $RoundRobin $pcount] != ""} {
    if {[lindex $RoundRobin $pcount] == $nick} {
      return
    }
    incr pcount
  }
  incr UnoPlayers
  lappend RoundRobin $nick
  lappend UnoIDX $nick
  if [info exist UnoHand($nick)] {unset UnoHand($nick)}
  if [info exist NickColor($nick)] {unset NickColor($nick)}
  set UnoHand($nick) ""
  set NickColor($nick) [colornick $UnoPlayers]
  # Re-Shuffle Deck
  UnoShuffle 7
  # Deal Cards To Player
  set Card ""
  while {[llength $UnoHand($nick)] != 7} {
    set pcardnum [expr {int(rand() * [llength $UnoDeck])}]
    set pcard [lindex $UnoDeck $pcardnum]
    set UnoDeck [lreplace ${UnoDeck} $pcardnum $pcardnum]
    lappend UnoHand($nick) $pcard
    append Card [CardColor $pcard]
  }
  if {$Debug > 1} { unolog $nick $UnoHand($nick) }
  ::uno::msg [::msgcat::mc uno_pljoin0 [::uno::nikclr $nick] [::uno::ad]]
  puts [::msgcat::mc uno_pljoin1 $nick]
  unontc $nick [::msgcat::mc uno_inhand $Card]
  return
}

#
# Reset Game Variables
#
proc UnoReset {} {
  global UnoOn UnoMode UnoPaused UnoPlayers RoundRobin UnoDeck ThisPlayer ThisPlayerIDX PlayCard
  global DiscardPile IsColorChange ColorPicker IsDraw UnoIDX MasterDeck CardStats
  global UnoStartTimer UnoSkipTimer UnoCycleTimer

  set UnoMode 0
  set UnoPaused 0
  set UnoPlayers 0
  set MasterDeck ""
  set UnoDeck ""
  set DiscardPile ""
  set RoundRobin ""
  set ThisPlayer ""
  set ThisPlayerIDX 0
  set PlayCard ""
  set IsColorChange 0
  set ColorPicker ""
  set IsDraw 0
  set UnoIDX ""
  set UnoAdNumber 0

  set CardStats(played) 0
  set CardStats(passed) 0
  set CardStats(drawn) 0
  set CardStats(wilds) 0
  set CardStats(draws) 0
  set CardStats(skips) 0
  set CardStats(revs) 0

  set UnoStartTimer ""
  set UnoSkipTimer ""
  set UnoCycleTimer ""

  return
}

#
# Add card(s) to players hand
#
proc UnoAddDrawToHand {cplayer idx num} {
  global UnoHand UnoDeck RoundRobin CardStats mysock
  # Check if deck needs reshuffling
  UnoShuffle $num
  set Card ""
  set newhand [expr [llength $UnoHand($cplayer)] + $num]
  while {[llength $UnoHand($cplayer)] != $newhand} {
    set pcardnum [expr {int(rand() * [llength $UnoDeck])}]
    set pcard [lindex $UnoDeck $pcardnum]
    set UnoDeck [lreplace ${UnoDeck} $pcardnum $pcardnum]
    lappend UnoHand($cplayer) $pcard
    append Card [CardColor $pcard]
  }
  showdraw $idx $Card
  incr CardStats(drawn) $num
}

#
# Remove played card from player's hand
#
proc UnoRemoveCardFromHand {cplayer pcard} {
  global UnoHand
  set UnoHand($cplayer) [lreplace $UnoHand($cplayer) $pcard $pcard]
}

#
# Add card to discard pile
#
proc AddToDiscardPile {playcard} {
  global DiscardPile
  if {[string range $playcard 1 1] != ""} {
    lappend DiscardPile $playcard
  }
}

#
# Draw a card
#
proc UnoDraw {nick uhost hand chan arg} {
  global UnoChan UnoMode UnoDeck ThisPlayer ThisPlayerIDX UnoHand RoundRobin IsDraw CardStats
  if {($chan != $UnoChan)||($UnoMode != 2)||($nick != $ThisPlayer)} {return}
  if {$IsDraw == 0} {
    set IsDraw 1
    UnoShuffle 1
    set dcardnum [expr {int(rand() * [llength $UnoDeck])}]
    set dcard [lindex $UnoDeck $dcardnum]
    lappend UnoHand($nick) $dcard
    set UnoDeck [lreplace ${UnoDeck} $dcardnum $dcardnum]
    append Card [CardColor $dcard]
    showdraw $ThisPlayerIDX $Card
    showwhodrew $nick
    incr CardStats(drawn)
    UnoAutoSkipReset
    return
  }
  unontc $nick [::msgcat::mc uno_alreadypick]
  UnoAutoSkipReset
  return
}

#
# Pass a turn
#
proc UnoPass {nick uhost hand chan arg} {
  global UnoChan UnoMode ThisPlayer IsDraw ThisPlayerIDX RoundRobin IsColorChange CardStats
  if {($chan != $UnoChan)||($UnoMode != 2)} {return}
  if {($nick != $ThisPlayer)||($IsColorChange == 1)} {return}
  UnoAutoSkipReset
  if {$IsDraw == 1} {
    incr CardStats(passed)
    set IsDraw 0
    UnoNextPlayer
    playpass $nick $ThisPlayer
    set Card [CardColorAll $ThisPlayer]
    showcards $ThisPlayerIDX $Card
    UnoRobotRestart
  } {
    unontc $nick [::msgcat::mc uno_pickbeforepass $nick]
  }
  return
}

#
# Color change
#
proc UnoColorChange {nick uhost hand chan arg} {
  global UnoChan UnoMode IsDraw PlayCard ColorPicker IsColorChange ThisPlayer ThisPlayerIDX RoundRobin Debug
  if {($chan != $UnoChan)||($UnoMode != 2)} {return}
  if {($nick != $ColorPicker)||($IsColorChange == 0)} {return}
  UnoAutoSkipReset
  regsub -all \[`.,!{}\ ] $arg "" arg
  set NewColor [string toupper [string range $arg 2 2]]
  if {$Debug == 1} {
    puts "arg : $arg"
    puts "Asked Color : $NewColor"
  }
  switch $NewColor {
    "B" { set PlayCard "B"; set Card " \00300,12 [::msgcat::mc uno_blue] \003 "}
    "G" { set PlayCard "G"; set Card " \00300,03 [::msgcat::mc uno_green] \003 "}
    "Y" { set PlayCard "Y"; set Card " \00301,08 [::msgcat::mc uno_yellow] \003 "}
    "R" { set PlayCard "R"; set Card " \00300,04 [::msgcat::mc uno_red] \003 "}
    default { unontc $nick [::msgcat::mc uno_selectcolor]; return }
  }
  UnoNextPlayer
  ::uno::msg [::msgcat::mc uno_selectedcolor [::uno::nikclr $ColorPicker] $Card [::uno::nikclr $ThisPlayer]]
  set Card [CardColorAll $ThisPlayer]
  showcards $ThisPlayerIDX $Card
  set ColorPicker ""
  set IsColorChange 0
  set IsDraw 0
  UnoRobotRestart
  return
}

#
# Skip card
#
proc PlayUnoSkipCard {nick pickednum crd} {
  global IsDraw ThisPlayer ThisPlayerIDX PlayCard RoundRobin CardStats
  set c0 [string range $crd 0 0]
  set c1 [string range $crd 1 1]
  set cip0 [string range $PlayCard 0 0]
  set cip1 [string range $PlayCard 1 1]
  if {$c1 != "S"} {return 0}
  if {($c0 != $cip0)&&($c1 != $cip1)} {return 0}
  incr CardStats(played)
  incr CardStats(skips)
  AddToDiscardPile $PlayCard
  UnoRemoveCardFromHand $nick $pickednum
  set PlayCard $crd
  set Card [CardColor $crd]
  set SkipPlayer $ThisPlayer
  UnoNextPlayer
  set SkippedPlayer [lindex $RoundRobin $ThisPlayerIDX]
  UnoNextPlayer
  # No Cards Left = Winner
  if {[check_unowin $SkipPlayer $Card] > 0} {
    showwin $SkipPlayer $Card
    UnoWin $SkipPlayer
    UnoCycle
    return 1
  }
  playskip $nick $Card $SkippedPlayer $ThisPlayer
  check_hasuno $SkipPlayer
  set Card [CardColorAll $ThisPlayer]
  showcards $ThisPlayerIDX $Card
  set IsDraw 0
  return 1
}

#
# Reverse card
#
proc PlayUnoReverseCard {nick pickednum crd} {
  global IsDraw UnoIDX ThisPlayer ThisPlayerIDX PlayCard RoundRobin CardStats
  set c0 [string range $crd 0 0]
  set c1 [string range $crd 1 1]
  set cip0 [string range $PlayCard 0 0]
  set cip1 [string range $PlayCard 1 1]
  if {$c1 != "R"} {return 0}
  if {($c0 != $cip0)&&($c1 != $cip1)} {return 0}
  incr CardStats(played)
  incr CardStats(revs)
  AddToDiscardPile $PlayCard
  UnoRemoveCardFromHand $nick $pickednum
  set PlayCard $crd
  set Card [CardColor $crd]
  # Reverse RoundRobin and Move To Next Player
  set NewRoundRobin ""
  set OrigOrderLength [llength $RoundRobin]
  set IDX $OrigOrderLength
  while {$OrigOrderLength != [llength $NewRoundRobin]} {
    set IDX [expr ($IDX - 1)]
    lappend NewRoundRobin [lindex $RoundRobin $IDX]
  }
  set Newindexorder ""
  set OrigindexLength [llength $UnoIDX]
  set IDX $OrigindexLength
  while {$OrigindexLength != [llength $Newindexorder]} {
    set IDX [expr ($IDX - 1)]
    lappend Newindexorder [lindex $UnoIDX $IDX]
  }
  set UnoIDX $Newindexorder
  set RoundRobin $NewRoundRobin
  set ReversePlayer $ThisPlayer
  # Next Player After Reversing RoundRobin
  set pcount 0
  while {$pcount != [llength $RoundRobin]} {
    if {[lindex $RoundRobin $pcount] == $ThisPlayer} {
      set ThisPlayerIDX $pcount
      break
    }
    incr pcount
  }
  # <3 Players Act Like A Skip Card
  if {[llength $RoundRobin] > 2} {
    incr ThisPlayerIDX
    if {$ThisPlayerIDX >= [llength $RoundRobin]} {set ThisPlayerIDX 0}
  }
  set ThisPlayer [lindex $RoundRobin $ThisPlayerIDX]
  # No Cards Left = Winner
  if {[check_unowin $ReversePlayer $Card] > 0} {
    showwin $ReversePlayer $Card
    UnoWin $ReversePlayer
    UnoCycle
    return 1
  }
  playcard $nick $Card $ThisPlayer
  check_hasuno $ReversePlayer
  set Card [CardColorAll $ThisPlayer]
  showcards $ThisPlayerIDX $Card
  set IsDraw 0
  return 1
}

#
# Draw Two card
#
proc PlayUnoDrawTwoCard {nick pickednum crd} {
  global IsDraw ThisPlayer ThisPlayerIDX PlayCard RoundRobin CardStats UnoWildDrawTwos
  set CardOk 0
  set c0 [string range $crd 0 0]
  set c2 [string range $crd 2 2]
  set cip0 [string range $PlayCard 0 0]
  set cip1 [string range $PlayCard 1 1]
  set cip2 [string range $PlayCard 2 2]
  if {$c2 != "T"} {return 0}
  if {$c0 == $cip0} {set CardOk 1}
  if {$cip2 == "T"} {set CardOk 1}
  if {$UnoWildDrawTwos != 0} {
    if {($cip1 != "")&&($cip2 != "F")} {set CardOk 1}
  }
  if {$CardOk == 1} {
    incr CardStats(draws)
    incr CardStats(played)
    AddToDiscardPile $PlayCard
    UnoRemoveCardFromHand $nick $pickednum
    set PlayCard $crd
    set Card [CardColor $crd]
    set DrawPlayer $ThisPlayer
    set DrawPlayerIDX $ThisPlayerIDX
    # Move to the player that draws
    UnoNextPlayer
    set PlayerThatDrew $ThisPlayer
    set PlayerThatDrewIDX $ThisPlayerIDX
    # Move To The Next Player
    UnoNextPlayer
    if {[check_unowin $nick $Card] > 0} {
      UnoAddDrawToHand $PlayerThatDrew $PlayerThatDrewIDX 2
      showwin $nick $Card
      UnoWin $nick
      UnoCycle
      return 1
    }
    playdraw $nick $Card $PlayerThatDrew $ThisPlayer
    UnoAddDrawToHand $PlayerThatDrew $PlayerThatDrewIDX 2
    check_hasuno $nick
    set Card [CardColorAll $ThisPlayer]
    showcards $ThisPlayerIDX $Card
    set IsDraw 0
    return 1
  }
  return 0
}

#
# Wild Draw Four card
#
proc PlayUnoWildDrawFourCard {nick pickednum crd isrobot} {
  global ThisPlayer ThisPlayerIDX PlayCard RoundRobin IsColorChange ColorPicker CardStats
  if {[string range $crd 2 2] != "F"} {return 0}
  incr CardStats(wilds)
  incr CardStats(played)
  set ColorPicker $ThisPlayer
  AddToDiscardPile $PlayCard
  UnoRemoveCardFromHand $nick $pickednum
  set PlayCard $crd
  set Card [CardColor $crd]
  # move to the player that draws
  UnoNextPlayer
  set PlayerThatDrew $ThisPlayer
  set PlayerThatDrewIDX $ThisPlayerIDX
  if {$isrobot > 0} {
    # choose color and move to next player
    set cip [UnoBotPickAColor]
    UnoNextPlayer
  }
  if {[check_unowin $nick $Card] > 0} {
    UnoAddDrawToHand $PlayerThatDrew $PlayerThatDrewIDX 4
    showwin $nick $Card
    UnoWin $nick
    UnoCycle
    return 1
  }
  if {$isrobot > 0} {
    botplaywildfour $ColorPicker $PlayerThatDrew $ColorPicker $cip $ThisPlayer
    set ColorPicker ""
    set IsColorChange 0
  } {
    playwildfour $nick $PlayerThatDrew $ColorPicker
    set IsColorChange 1
  }
  UnoAddDrawToHand $PlayerThatDrew $PlayerThatDrewIDX 4
  check_hasuno $nick
  if {$isrobot > 0} {
    set Card [CardColorAll $ThisPlayer]
    showcards $ThisPlayerIDX $Card
  }
  set IsDraw 0
  return 1
}

#
# Wild card
#
proc PlayUnoWildCard {nick pickednum crd isrobot} {
  global IsDraw ThisPlayer ThisPlayerIDX PlayCard RoundRobin IsColorChange ColorPicker CardStats
  if {[string range $crd 0 0] != "W"} {return 0}
  incr CardStats(wilds)
  incr CardStats(played)
  set ColorPicker $ThisPlayer
  AddToDiscardPile $PlayCard
  UnoRemoveCardFromHand $nick $pickednum
  set PlayCard $crd
  set Card [CardColor $crd]
  # Ok to remove this?
  #set ThisPlayer [lindex $RoundRobin $ThisPlayerIDX]
  #set DrawnPlayer $ThisPlayer
  if {$isrobot > 0} {
    # Make A Color Choice
    set cip [UnoBotPickAColor]
    UnoNextPlayer
  }
  # No Cards Left = Winner
  if {[check_unowin $nick $Card] > 0} {
    showwin $nick $Card
    UnoWin $nick
    UnoCycle
    return 1
  }
  if {$isrobot > 0} {
    botplaywild $nick $ColorPicker $cip $ThisPlayer
    set ColorPicker ""
    set Card [CardColorAll $ThisPlayer]
    showcards $ThisPlayerIDX $Card
    set IsColorChange 0
  } {
    playwild $nick $ColorPicker
    set IsColorChange 1
  }
  check_hasuno $nick
  set IsDraw 0
  return 1
}

#
# Number card
#
proc PlayUnoNumberCard {nick pickednum crd} {
  global IsDraw ThisPlayer ThisPlayerIDX PlayCard RoundRobin CardStats
  set CardOk 0
  set c1 [string range $crd 0 0]
  set c2 [string range $crd 1 1]
  set cip1 [string range $PlayCard 0 0]
  set cip2 [string range $PlayCard 1 1]
  if {$c2 == -1} {return 0}
  if {$c1 == $cip1} {set CardOk 1}
  if {($cip2 != "")} {
    if {$c2 == $cip2} {set CardOk 1}
  }
  if {$CardOk == 1} {
    incr CardStats(played)
    AddToDiscardPile $PlayCard
    UnoRemoveCardFromHand $nick $pickednum
    set PlayCard $crd
    set Card [CardColor $crd]
    set NumberCardPlayer $ThisPlayer
    UnoNextPlayer
    if {[check_unowin $NumberCardPlayer $Card] > 0} {
      showwin $NumberCardPlayer $Card
      UnoWin $NumberCardPlayer
      UnoCycle
      return 1
    }
    playcard $nick $Card $ThisPlayer
    check_hasuno $NumberCardPlayer
    set Card [CardColorAll $ThisPlayer]
    showcards $ThisPlayerIDX $Card
    set IsDraw 0
    return 1
  }
  unontc $nick [::msgcat::mc uno_invalidcard]
  return 0
}

#
# Attempt to find card in hand
#
proc UnoFindCard {nick pickednum crd IsRobot} {
  global UnoRobot ThisPlayer ThisPlayerIDX
  #if {$Debug > 1} {unolog $UnoRobot "UnoFindCard: [lindex $UnoHand($ThisPlayer) $pickednum"}
  # Wild Draw Four
  set FoundCard [PlayUnoWildDrawFourCard $nick $pickednum $crd $IsRobot]
  if {$FoundCard == 1} {return 4}
  # Wild
  set FoundCard [PlayUnoWildCard $nick $pickednum $crd $IsRobot]
  if {$FoundCard == 1} {return 5}
  # Draw Two
  set FoundCard [PlayUnoDrawTwoCard $nick $pickednum $crd]
  if {$FoundCard == 1} {return 3}
  # Skip
  set FoundCard [PlayUnoSkipCard $nick $pickednum $crd]
  if {$FoundCard == 1} {return 1}
  # Reverse
  set FoundCard [PlayUnoReverseCard $nick $pickednum $crd]
  if {$FoundCard == 1} {return 2}
  # Number card
  set FoundCard [PlayUnoNumberCard $nick $pickednum $crd]
  if {$FoundCard == 1} {return 6}
  return 0
}

#
# Play a card
#
proc UnoPlayCard {nick uhost hand chan arg} {
  global UnoChan UnoMode IsDraw IsColorChange ColorPicker UnoPlayers RoundRobin UnoHand ThisPlayer Debug
  if {($chan != $UnoChan)||($UnoMode != 2)||($nick != $ThisPlayer)} {return}
  UnoAutoSkipReset
  if {$IsColorChange == 1} {return}
  regsub -all \[`,.!{}\ ] $arg "" arg
  if {$arg == ""} {return}
  set pcard [string toupper [string range $arg 2 end]]
  set CardInPlayerHand 0
  set pcount 0
  if {$Debug==1} {
    puts "arg         : $arg"
    puts "Player hand : $UnoHand($nick)"
    puts "Asked card  : $pcard"
  }
  while {[lindex $UnoHand($nick) $pcount] != ""} {
    if {$pcard == [lindex $UnoHand($nick) $pcount]} {
      set pcardnum $pcount
      set CardInPlayerHand 1
      break
    }
    incr pcount
  }
  if {$CardInPlayerHand == 0} {
    unontc $nick [::msgcat::mc uno_notinhand]
    return
  }
  set CardFound [UnoFindCard $nick $pcardnum $pcard 0]
  switch $CardFound {
    0 {return}
    4 {return}
    5 {return}
    default {UnoRobotRestart; return}
  }
}

#
# Robot Player
#
proc UnoRobotPlayer {} {
  global Debug UnoIDX IsDraw IsColorChange ColorPicker UnoMode UnoPlayers RoundRobin UnoDeck UnoHand ThisPlayer ThisPlayerIDX PlayCard CardStats UnoRobot
  # Check for a valid card in hand
  set CardOk 0
  set IsDraw 0
  set CardCount 0
  set cip1 [string range $PlayCard 0 0]
  set cip2 [string range $PlayCard 1 1]
  while {$CardCount < [llength $UnoHand($ThisPlayer)]} {
    set playcard [lindex $UnoHand($ThisPlayer) $CardCount]
    set c1 [string range $playcard 0 0]
    set c2 [string range $playcard 1 1]
    #if {$Debug > 1} {unolog $UnoRobot "Trying: $playcard"}
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
    set CardFound [UnoFindCard $UnoRobot $pcardnum $pcard 1]
    switch $CardFound {
      0 {}
      5 {return}
      6 {return}
      default {UnoRobotRestart; return}
    }
  }
  # Bot draws a card
  UnoShuffle 1
  set dcardnum [expr {int(rand() * [llength $UnoDeck])}]
  set dcard [lindex $UnoDeck $dcardnum]
  lappend UnoHand($UnoRobot) "$dcard"
  set UnoDeck [lreplace ${UnoDeck} $dcardnum $dcardnum]
  showwhodrew $UnoRobot
  set CardOk 0
  set CardCount 0
  incr CardStats(drawn)
  while {$CardCount < [llength $UnoHand($ThisPlayer)]} {
    set playcard [lindex $UnoHand($ThisPlayer) $CardCount]
    set c1 [string range $playcard 0 0]
    set c2 [string range $playcard 1 1]
    # if {$Debug > 1} {unolog $UnoRobot "DrawTry: $playcard"}
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
    set CardFound [UnoFindCard $UnoRobot $pcardnum $pcard 1]
    if {$CardFound == 1} {UnoRobotRestart; return}
    switch $CardFound {
      0 {}
      5 {return}
      6 {return}
      default {UnoRobotRestart; return}
    }
  } {
    incr CardStats(passed)
    set IsDraw 0
    UnoNextPlayer
    playpass $UnoRobot $ThisPlayer
    set Card [CardColorAll $ThisPlayer]
    showcards $ThisPlayerIDX $Card
  }
  return
}

#
# Pause play
#
proc UnoPause {nick uhost hand chan arg} {
  global UnoChan UnoOn UnoMode UnoPaused
  if {$chan != $UnoChan} {return}
  if {$UnoOn != 1} {return}
  if {$UnoMode != 2} {return}
  if {[is_admin $nick]} {
    if {$UnoPaused == 0} {
      set UnoPaused 1
      ::uno::msg [::msgcat::mc uno_pauseon [::uno::ad] $nick]
    } {
      set UnoPaused 0
      UnoAutoSkipReset
      ::uno::msg [::msgcat::mc uno_pauseoff [::uno::ad] $nick]
    }
  }
}

#
# Remove user from play
#
proc UnoRemove {nick uhost hand chan arg} {
  global UnoChan UnoOn UnoCycleTime UnoIDX UnoPlayers ThisPlayer ThisPlayerIDX RoundRobin UnoDeck DiscardPile UnoHand IsColorChange ColorPicker NickColor
  global mysock
  if {$chan != $UnoChan} {return}
  if {$UnoOn == 0} {return}
  regsub -all \[`,.!{}] $arg "" arg
  # Allow Ops To Remove Another Player
  set UnoOpRemove 0
  if {[string length $arg] > 0} {
    if {[is_admin $nick]} {
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
  while {[lindex $RoundRobin $pcount] != ""} {
    if {[string tolower [lindex $RoundRobin $pcount]] == [string tolower $nick]} {
      set PlayerFound 1
      set FoundIDX $pcount
      set nick [lindex $RoundRobin $pcount]
      break
    }
    incr pcount
  }
  if {$PlayerFound == 1} {
    if {$UnoOpRemove > 0} {
      ::uno::msg [::msgcat::mc uno_rembyop0 [::uno::nikclr $nick] $UnoOpNick]
    } {
      unontc $nick [::msgcat::mc uno_rembyop1]
      ::uno::msg [::msgcat::mc uno_rembyop2 [::uno::nikclr $nick]]
    }
    # Player Was ColorPicker
    if {$IsColorChange == 1} {
      if {$nick == $ColorPicker} {
        # Make A Color Choice
        set cip [UnoPickAColor]
        ::uno::msg [::msgcat::mc uno_shouldclrchg [::uno::nikclr $nick] $cip]
        set IsColorChange 0
      } {
        if {$mysock(debug)==1} { puts "UnoRemove: IsColorChange Set but $nick not ColorPicker" }
      }
    }
    if {$nick == $ThisPlayer} {
      UnoNextPlayer
      if {$UnoPlayers > 2} {
        ::uno::msg [::msgcat::mc uno_removenext [::uno::nikclr $nick] [::uno::nikclr $ThisPlayer] "%s\017 a joué, au tour de %s."
      }
      UnoAutoSkipReset
    }
    set UnoPlayers [expr ($UnoPlayers -1)]
    # Remove Player From Game And Put Cards Back In Deck
    if {$UnoPlayers > 1} {
      set RoundRobin [lreplace ${RoundRobin} $FoundIDX $FoundIDX]
      set UnoIDX [lreplace ${UnoIDX} $FoundIDX $FoundIDX]
      lappend DiscardPile "$UnoHand($nick)"
      unset UnoHand($nick)
      unset NickColor($nick)
    }
    set pcount 0
    while {[lindex $RoundRobin $pcount] != ""} {
      if {[lindex $RoundRobin $pcount] == $ThisPlayer} {
        set ThisPlayerIDX $pcount
        break
      }
      incr pcount
    }
    if {$UnoPlayers == 1} {
      showwindefault $ThisPlayer
      UnoWin $ThisPlayer
      UnoCycle
      return
    }
    UnoRobotRestart
  } {
    # Player not in current game
    return
  }
  if {$UnoPlayers == 0} {
    ::uno::msg [::msgcat::mc uno_nowin [::uno::ad]]
    UnoCycle
  }
  return
}

#
# Move to next player
#
proc UnoNextPlayer {} {
  global ThisPlayer ThisPlayerIDX RoundRobin
  incr ThisPlayerIDX
  if {$ThisPlayerIDX >= [llength $RoundRobin]} {set ThisPlayerIDX 0}
  set ThisPlayer [lindex $RoundRobin $ThisPlayerIDX]
}

#
# Pick a random color for skipped/removed players
#
proc UnoPickAColor {} {
  global PlayCard
  set ucolors "r g b y"
  set pcol [string tolower [lindex $ucolors [expr {int(rand() * [llength $ucolors])}]]]
  switch $pcol {
    "r" {set PlayCard "R"; return "\00300,04 [::msgcat::mc uno_red] \003"}
    "g" {set PlayCard "G"; return "\00300,03 [::msgcat::mc uno_green] \003"}
    "b" {set PlayCard "B"; return "\00300,12 [::msgcat::mc uno_blue] \003"}
    "y" {set PlayCard "Y"; return "\00301,08 [::msgcat::mc uno_yellow] \003"}
  }
}

#
# Robot picks a color by checking hand for 1st color card
# found with matching color, else picks color at random
#
proc UnoBotPickAColor {} {
  global PlayCard UnoHand ThisPlayer
  set CardCount 0
  while {$CardCount < [llength $UnoHand($ThisPlayer)]} {
    set thiscolor [string range [lindex $UnoHand($ThisPlayer) $CardCount] 0 0]
    switch $thiscolor {
      "R" {set PlayCard "R"; return "\00300,04 [::msgcat::mc uno_red] \003"}
      "G" {set PlayCard "G"; return "\00300,03 [::msgcat::mc uno_green] \003"}
      "B" {set PlayCard "B"; return "\00300,12 [::msgcat::mc uno_blue] \003"}
      "Y" {set PlayCard "Y"; return "\00301,08 [::msgcat::mc uno_yellow] \003"}
    }
    incr CardCount
  }
  set ucolors "r g b y"
  set pcol [string tolower [lindex $ucolors [expr {int(rand() * [llength $ucolors])}]]]
  switch $pcol {
    "r" {set PlayCard "R"; return "\00300,04 [::msgcat::mc uno_red] \003"}
    "g" {set PlayCard "G"; return "\00300,03 [::msgcat::mc uno_green] \003"}
    "b" {set PlayCard "B"; return "\00300,12 [::msgcat::mc uno_blue] \003"}
    "y" {set PlayCard "Y"; return "\00301,08 [::msgcat::mc uno_yellow] \003"}
  }
}

#
# Set robot for next turn
#
proc UnoRobotRestart {} {
  global UnoMode ThisPlayerIDX RobotRestartPeriod UnoBotTimer
  if {$UnoMode != 2} {return}
  if {![uno_isrobot $ThisPlayerIDX]} {return}
  set UnoBotTimer [after [expr {int($RobotRestartPeriod * 1000)}] UnoRobotPlayer]
}

#
# Reset autoskip timer
#
proc UnoAutoSkipReset {} {
  global AutoSkipPeriod UnoMode UnoSkipTimer
  ### catch {after cancel $UnoSkipTimer}
  if {$UnoMode == 2} {
    ### set UnoSkipTimer [after [expr {int($AutoSkipPeriod * 1000 * 60)}] UnoAutoSkip]
  }
}


#
# Read config file
#
proc Uno_ReadCFG {} {
  global UnoCFGFile UnoLastMonthCards UnoLastMonthGames UnoPointsName UnoScoreFile UnoRobot UnoChan UnoFast UnoHigh UnoPlayed UnoStopAfter UnoBonus
  global UnoRecordHigh UnoRecordFast UnoRecordCard UnoRecordWins UnoRecordPlayed UnoWildDrawTwos
  if {[file exist $UnoCFGFile]} {
    set f [open $UnoCFGFile r]
    while {[gets $f s] != -1} {
      set kkey [string tolower [lindex [split $s "="] 0]]
      set kval [lindex [split $s "="] 1]
      switch $kkey {
        botname {set UnoRobot $kval}
        channel {set UnoChan $kval}
        points {set UnoPointsName $kval}
        scorefile {set UnoScoreFile $kval}
        stopafter {set UnoStopAfter $kval}
        wilddrawtwos {set UnoWildDrawTwos $kval}
        lastmonthcard1 {set UnoLastMonthCards(0) $kval}
        lastmonthcard2 {set UnoLastMonthCards(1) $kval}
        lastmonthcard3 {set UnoLastMonthCards(2) $kval}
        lastmonthwins1 {set UnoLastMonthGames(0) $kval}
        lastmonthwins2 {set UnoLastMonthGames(1) $kval}
        lastmonthwins3 {set UnoLastMonthGames(2) $kval}
        fast {set UnoFast $kval}
        high {set UnoHigh $kval}
        played {set UnoPlayed $kval}
        bonus {set UnoBonus $kval}
        recordhigh {set UnoRecordHigh $kval}
        recordfast {set UnoRecordFast $kval}
        recordcard {set UnoRecordCard $kval}
        recordwins {set UnoRecordWins $kval}
        recordplayed {set UnoRecordPlayed $kval}
      }
    }
    close $f
    if {$UnoStopAfter < 0} {set UnoStopAfter 0}
    if {$UnoBonus < 0} {set UnoBonus 1000}
    if {($UnoWildDrawTwos < 0)||($UnoWildDrawTwos > 1)} {set UnoWildDrawTwos 0}
    return
  }
  Uno_WriteCFG
  return
}

#
# Write config file
#
proc Uno_WriteCFG {} {
  global UnoCFGFile UnoLastMonthCards UnoLastMonthGames UnoPointsName UnoScoreFile UnoRobot UnoChan UnoFast UnoHigh UnoPlayed UnoStopAfter UnoBonus
  global UnoRecordHigh UnoRecordFast UnoRecordCard UnoRecordWins UnoRecordPlayed UnoWildDrawTwos
  set f [open $UnoCFGFile w]
  puts $f "# This file is automatically overwritten"
  puts $f "BotName=$UnoRobot"
  puts $f "Channel=$UnoChan"
  puts $f "Points=$UnoPointsName"
  puts $f "ScoreFile=$UnoScoreFile"
  puts $f "StopAfter=$UnoStopAfter"
  puts $f "WildDrawTwos=$UnoWildDrawTwos"
  puts $f "LastMonthCard1=$UnoLastMonthCards(0)"
  puts $f "LastMonthCard2=$UnoLastMonthCards(1)"
  puts $f "LastMonthCard3=$UnoLastMonthCards(2)"
  puts $f "LastMonthWins1=$UnoLastMonthGames(0)"
  puts $f "LastMonthWins2=$UnoLastMonthGames(1)"
  puts $f "LastMonthWins3=$UnoLastMonthGames(2)"
  puts $f "Fast=$UnoFast"
  puts $f "High=$UnoHigh"
  puts $f "Played=$UnoPlayed"
  puts $f "Bonus=$UnoBonus"
  puts $f "RecordHigh=$UnoRecordHigh"
  puts $f "RecordFast=$UnoRecordFast"
  puts $f "RecordCard=$UnoRecordCard"
  puts $f "RecordWins=$UnoRecordWins"
  puts $f "RecordPlayed=$UnoRecordPlayed"
  close $f
  return
}

#
# Read score file
#
proc UnoReadScores {} {
  global unogameswon unoptswon UnoScoreFile UnoRobot
  if [info exists unogameswon] { unset unogameswon }
  if [info exists unoptswon] { unset unoptswon }
  if ![file exists $UnoScoreFile] {
    set f [open $UnoScoreFile w]
    puts $f "$UnoRobot 0 0"
    close $f
  }
  set f [open $UnoScoreFile r]
  while {[gets $f s] != -1} {
    set unogameswon([lindex [split $s] 0]) [lindex $s 1]
    set unoptswon([lindex [split $s] 0]) [lindex $s 2]
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
proc UnoOrder {nick uhost hand chan arg} {
  global UnoChan UnoMode UnoPlayers RoundRobin
  if {($chan != $UnoChan)||($UnoMode < 2)} {return}
  ::uno::msg [::msgcat::mc uno_order $UnoPlayers $RoundRobin]
  return
}

#
# Show game running time
#
proc UnoTime {nick uhost hand chan arg} {
  global UnoChan UnoMode
  if {($chan != $UnoChan)||($UnoMode != 2)} {return}
  ::uno::msg [::msgcat::mc uno_duration [duration [game_time]]
  return
}

#
# Show player what cards they hold
#
proc UnoShowCards {nick uhost hand chan arg} {
  global UnoChan UnoMode UnoHand ThisPlayerIDX
  if {($chan != $UnoChan)||($UnoMode != 2)} {return}
  if [info exist UnoHand($nick)] {
    set Card ""
    set ccnt 0
    while {[llength $UnoHand($nick)] != $ccnt} {
      set pcard [lindex $UnoHand($nick) $ccnt]
      append Card [CardColor $pcard]
      incr ccnt
    }
    if {![uno_isrobot $ThisPlayerIDX]} {
      unontc $nick [::msgcat::mc uno_inhand $Card]
    }
  }
  return
}

#
# Show current player
#
proc UnoTurn {nick uhost hand chan arg} {
  global UnoChan UnoMode ThisPlayer RoundRobin UnoMode
  if {($chan != $UnoChan)||($UnoMode != 2)} {return}
  if {[llength $RoundRobin] < 1 } {return}
  ::uno::msg [::msgcat::mc uno_currpl $ThisPlayer]
  return
}

#
# Show current top card
#
proc UnoTopCard {nick uhost hand chan arg} {
  global PlayCard UnoChan UnoMode
  if {($chan != $UnoChan)||($UnoMode != 2)} {return}
  set pcard $PlayCard
  set Card [CardColor $pcard]
  ::uno::msg [::msgcat::mc uno_ingamecard $Card]
  return
}

#
# Show card stats
#
proc UnoCardStats {nick uhost hand chan arg} {
  global UnoChan UnoMode CardStats
  if {($chan != $UnoChan)||($UnoMode != 2)} {return}
  ::uno::msg [::msgcat::mc uno_cardstats $CardStats(played) [format "%3.1f" [get_ratio $CardStats(passed) $CardStats(drawn)]] [expr $CardStats(skips) +$CardStats(revs)] $CardStats(draws) $CardStats(wilds)] 
  return
}

#
# Card count
#
proc UnoCount {nick uhost hand chan arg} {
  global RoundRobin UnoHand UnoMode UnoChan
  if {($chan != $UnoChan)||($UnoMode != 2)} {return}
  set ordcnt 0
  set crdcnt ""
  while {[lindex $RoundRobin $ordcnt] != ""} {
    append crdcnt "[::msgcat::mc uno_count [lindex $RoundRobin $ordcnt] [llength $UnoHand([lindex $RoundRobin $ordcnt])]] "
    incr ordcnt
  }
  ::uno::msg "$crdcnt"
  return
}

#
# Show player's score
#
proc UnoWon {nick uhost hand chan arg} {
  global UnoScoreFile UnoPointsName
  regsub -all \[`,.!] $arg "" arg
  if {[string length $arg] == 0} {set arg $nick}
  set scorer [string tolower $arg]
  set pflag 0
  set f [open $UnoScoreFile r]
  while {[gets $f sc] != -1} {
    set cnick [string tolower [lindex [split $sc] 0]]
    if {$cnick == $scorer} {
      set pmsg [::msgcat::mc uno_won [lindex [split $sc] 0] [lindex $sc 2] $UnoPointsName [lindex $sc 1]]
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
proc UnoTopTen {nick uhost hand chan arg} {
  global UnoChan
  if {$chan != $UnoChan} {return}
  UnoTop10 1
  return
}
proc UnoTopTenWon {nick uhost hand chan arg} {
  global UnoChan
  if {$chan != $UnoChan} {return}
  UnoTop10 0
  return
}

#
# Display last month's top3
#
proc UnoTopThreeLast {nick uhost hand chan arg} {
  global UnoChan
  if {$chan != $UnoChan} {return}
  UnoLastMonthTop3 $nick $uhost $hand $chan 0
  ::uno::msg " "
  UnoLastMonthTop3 $nick $uhost $hand $chan 1
  return
}

#
# Display month fastest game
#
proc UnoTopFast {nick uhost hand chan arg} {
  global UnoChan UnoFast
  if {$chan != $UnoChan} {return}
  ::uno::msg [::msgcat::mc uno_topfast [lindex [split $UnoFast] 0] [duration [lindex $UnoFast 1]]]
  return
}

#
# Display month high score
#
proc UnoHighScore {nick uhost hand chan arg} {
  global UnoChan UnoHigh UnoPointsName
  if {$chan != $UnoChan} {return}
  ::uno::msg [::msgcat::mc uno_highscore [lindex [split $UnoHigh] 0] [lindex $UnoHigh 1] $UnoPointsName]
  return
}

#
# Display month most cards played
#
proc UnoPlayed {nick uhost hand chan arg} {
  global UnoChan UnoPlayed
  if {$chan != $UnoChan} {return}
  ::uno::msg [::msgcat::mc uno_played [lindex [split $UnoPlayed] 0] [lindex $UnoPlayed 1]]
  return
}

#
# Show all-time records
#
proc UnoRecords {nick uhost hand chan arg} {
  global UnoChan UnoRecordFast UnoRecordHigh UnoRecordCard UnoRecordWins UnoRecordPlayed
  if {$chan != $UnoChan} {return}
  ::uno::msg [::msgcat::mc uno_records $UnoRecordCard $UnoRecordWins [lindex $UnoRecordFast 0] [duration [lindex $UnoRecordFast 1]] $UnoRecordHigh $UnoRecordPlayed]
  return
}

#
# Display month top10
#
proc UnoTop10 {mode} {
  global UnoScoreFile unsortedscores UnoPointsName UnoRobot
  if {($mode < 0)||($mode > 1)} {set mode 0}
  switch $mode {
    0 {set winners [::msgcat::mc uno_topten0]}
    1 {set winners [::msgcat::mc uno_topten1]}
  }
  if ![file exists $UnoScoreFile] {
    set f [open $UnoScoreFile w]
    puts $f "$UnoRobot 0 0"
    ::uno::msg [::msgcat::mc uno_emptyscorefile]
    close $f
    return
  }
  if [info exists unsortedscores] {unset unsortedscores}
  if [info exists top10] {unset top10}
  set f [open $UnoScoreFile r]
  while {[gets $f s] != -1} {
    switch $mode {
      0 {set unsortedscores([lindex [split $s] 0]) [lindex $s 1]}
      1 {set unsortedscores([lindex [split $s] 0]) [lindex $s 2]}
    }
  }
  close $f
  for {set s 0} {$s < 10} {incr s} {
    set top10($s) "[::msgcat::mc uno_nobody] 0"
  }
  set s 0
  foreach n [lsort -decreasing -command UnoSortScores [array names unsortedscores]] {
    set top10($s) "$n $unsortedscores($n)"
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
proc UnoLastMonthTop3 {nick uhost hand chan arg} {
  global UnoChan UnoLastMonthCards UnoLastMonthGames UnoPointsName
  if {$chan != $UnoChan} {return}
  set UnoTop3 " "
  if {$arg == 0} {
    if [info exists UnoLastMonthCards] {
      set UnoTop3 "[::msgcat::mc uno_top3cards $UnoPointsName] "
      for { set s 0} { $s < 3 } { incr s} {
        append UnoTop3 "\00300,06 #[expr $s +1] \00300,10 $UnoLastMonthCards($s) "
      }
    }
  } {
    if [info exists UnoLastMonthGames] {
      set UnoTop3 "[::msgcat::mc uno_top3games] "
      for { set s 0} { $s < 3 } { incr s} {
        append UnoTop3 "\00300,06 #[expr $s +1] \00300,10 $UnoLastMonthGames($s) "
      }
    }
  }
  ::uno::msg "$UnoTop3"
}

#
# Show game help
#
proc UnoCmds {nick uhost hand chan arg} {
  global UnoChan mysock
  if {$mysock(debug)==1} {
    puts "UNO : !unocmds par $nick."
    fsend $mysock(sock) ":$mysock(nick) PRIVMSG $mysock(adminchan) :\00304UNO :\017 !unocmds par \00302$nick\017."
  }
  unontc $nick [::msgcat::mc uno_helpcmd]
  unontc $nick [::msgcat::mc uno_helpstats]
  unontc $nick [::msgcat::mc uno_helpcards]
  unontc $nick [::msgcat::mc uno_helpgame]
  return
}

#
# Uno version
#
proc UnoVersion {nick uhost hand chan arg} {
  global UnoVersion
  ::uno::msg [::msgcat::mc uno_version [::uno::ad] $UnoVersion]
  return
}

#
# Clear top10 and write monthly scores
#
proc UnoNewMonth {min hour day month year} {
  global unsortedscores unogameswon unoptswon UnoLastMonthCards UnoLastMonthGames UnoScoreFile UnoRobot
  global UnoFast UnoHigh UnoPlayed UnoRecordFast UnoRecordHigh UnoRecordPlayed UnoRecordCard UnoRecordWins
  global mysock
  set lmonth [UnoLastMonthName $month]
  ::uno::msg [::msgcat::mc uno_erasemonth [::uno::ad]]
  set UnoMonthFileName "$UnoScoreFile.$lmonth"
  # Read Current Scores
  UnoReadScores
  # Write To Old Month File
  if ![file exists $UnoMonthFileName] {
    set f [open $UnoMonthFileName w]
     foreach n [array names unogameswon] {
       puts $f "$n $unogameswon($n) $unoptswon($n)"
     }
    close $f
  }
  # Find Top 3 Card Holders and Game Winners
  set mode 0
  while {$mode < 2} {
    if [info exists unsortedscores] {unset unsortedscores}
    if [info exists top10] {unset top10}
    set f [open $UnoScoreFile r]
    while {[gets $f s] != -1} {
      switch $mode {
        0 {set unsortedscores([lindex [split $s] 0]) [lindex $s 1]}
        1 {set unsortedscores([lindex [split $s] 0]) [lindex $s 2]}
      }
    }
    close $f
    set s 0
    foreach n [lsort -decreasing -command UnoSortScores [array names unsortedscores]] {
      set top10($s) "$n $unsortedscores($n)"
      incr s
    }
    for {set s 0} {$s < 3} {incr s} {
      if {[lindex $top10($s) 1] > 0} {
       switch $mode {
          0 {set UnoLastMonthGames($s) "[lindex [split $top10($s)] 0] [lindex $top10($s) 1]"}
          1 {set UnoLastMonthCards($s) "[lindex [split $top10($s)] 0] [lindex $top10($s) 1]"}
        }
      } {
        switch $mode {
          0 {set UnoLastMonthGames($s) "[::msgcat::mc uno_nobody] 0"}
          1 {set UnoLastMonthCards($s) "[::msgcat::mc uno_nobody] 0"}
        }
      }
    }
    incr mode
  }
  # Update records
  if {[lindex $UnoFast 1] < [lindex $UnoRecordFast 1]} {set UnoRecordFast $UnoFast}
  if {[lindex $UnoHigh 1] > [lindex $UnoRecordHigh 1]} {set UnoRecordHigh $UnoHigh}
  if {[lindex $UnoPlayed 1] > [lindex $UnoRecordPlayed 1]} {set UnoRecordPlayed $UnoPlayed}
  if {[lindex $UnoLastMonthCards(0) 1] > [lindex $UnoRecordCard 1]} {set UnoRecordCard $UnoLastMonthCards(0)}
  if {[lindex $UnoLastMonthGames(0) 1] > [lindex $UnoRecordWins 1]} {set UnoRecordWins $UnoLastMonthGames(0)}
  # Wipe last months records
  set UnoFast "$UnoRobot 60"
  set UnoHigh "$UnoRobot 100"
  set UnoPlayed "$UnoRobot 100"
  # Save Top3 And Records To Config File
  Uno_WriteCFG
  # Wipe This Months Score File
  set f [open $UnoScoreFile w]
  puts $f "$UnoRobot 0 0"
  close $f
  if {$mysock(debug)==1} { puts "Month scores erased." }
  return
}

#
# Update score of winning player
#
proc UnoUpdateScore {winner cardtotals} {
  global unogameswon unoptswon UnoScoreFile
  UnoReadScores
  if {[info exists unogameswon($winner)]} {
    incr unogameswon($winner)
  } {
    set unogameswon($winner) 1
  }
  if {[info exists unoptswon($winner)]} {
    incr unoptswon($winner) $cardtotals
  } {
    set unoptswon($winner) $cardtotals
  }
  set f [open $UnoScoreFile w]
  foreach n [array names unogameswon] {
    puts $f "$n $unogameswon($n) $unoptswon($n)"
  }
  close $f
  return
}

#
# Display winner and game statistics
#
proc UnoWin {winner} {
  global UnoHand ThisPlayer RoundRobin UnoPointsName CardStats UnoMode UnoCycleTime UnoFast UnoHigh UnoPlayed UnoBonus
  set cardtotals 0
  set UnoMode 3
  set ThisPlayerIDX 0
  set needCFGWrite 0
  set UnoTime [game_time]
  ::uno::msg [::msgcat::mc uno_end0]
  # Total up all player's cards
  while {$ThisPlayerIDX != [llength $RoundRobin]} {
    set Card ""
    set ThisPlayer [lindex $RoundRobin $ThisPlayerIDX]
    if {$ThisPlayer != $winner} {
      set ccount 0
      while {[lindex $UnoHand($ThisPlayer) $ccount] != ""} {
        set cardtotal [lindex $UnoHand($ThisPlayer) $ccount]
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
      set Card [CardColorAll $ThisPlayer]
      ::uno::msg "[strpad [::uno::nikclr $ThisPlayer] 12] $Card"
    }
    incr ThisPlayerIDX
  }
  # Check high score record
  set HighScore [lindex $UnoHigh 1]
  if {$cardtotals > $HighScore} {
    ::uno::msg [::msgcat::mc uno_endhighscore $winner $UnoBonus $UnoPointsName]
    set UnoHigh "$winner $cardtotals"
    incr cardtotals $UnoBonus
    set needCFGWrite 1
  }
  # Check played cards record
  set HighPlayed [lindex $UnoPlayed 1]
  if {$CardStats(played) > $HighPlayed} {
    ::uno::msg [::msgcat::mc uno_endplayed $winner $UnoBonus $UnoPointsName]
    set UnoPlayed "$winner $CardStats(played)"
    incr cardtotals $UnoBonus
    set needCFGWrite 1
  }
  # Check fast game record
  set FastRecord [lindex $UnoFast 1]
  if {$UnoTime < $FastRecord} {
    ::uno::msg [::msgcat::mc uno_endtime $winner $UnoBonus $UnoPointsName]
    incr cardtotals $UnoBonus
    set UnoFast "$winner $UnoTime"
    set needCFGWrite 1
  }
  # Winner
  ::uno::msg [::msgcat::mc uno_endwinner $winner $cardtotals $UnoPointsName [duration $UnoTime]]
  # Card stats
  ::uno::msg [::msgcat::mc uno_cardstats $CardStats(played) [format "%3.1f" [get_ratio $CardStats(passed) $CardStats(drawn)]] [expr $CardStats(skips) + $CardStats(revs)] $CardStats(draws) $CardStats(wilds)]
  ::uno::msg [::msgcat::mc uno_endnextgame [::uno::ad] $UnoCycleTime]
  # Write scores
  UnoUpdateScore $winner $cardtotals
  # Write records
  if {$needCFGWrite > 0} {Uno_WriteCFG}
  return
}

#
# Re-Shuffle deck
#
proc UnoShuffle {len} {
  global UnoDeck DiscardPile
  if {[llength $UnoDeck] >= $len} { return }
  ::uno::msg [::msgcat::mc uno_shuffle [::uno::ad]]
  lappend DiscardPile "$UnoDeck"
  set UnoDeck ""
  set NewDeckSize [llength $DiscardPile]
  while {[llength $UnoDeck] != $NewDeckSize} {
    set pcardnum [expr {int(rand() * [llength $DiscardPile])}]
    set pcard [lindex $DiscardPile $pcardnum]
    lappend UnoDeck "$pcard"
    set DiscardPile [lreplace ${DiscardPile} $pcardnum $pcardnum]
  }
  return
}

#
# Score advertiser
#
proc UnoScoreAdvertise {} {
  global UnoChan UnoAdNumber UnoRobot
  ::uno::msg " "
  switch $UnoAdNumber {
    0 {UnoTop10 0}
    1 {UnoLastMonthTop3 $UnoRobot none none $UnoChan 0}
    2 {UnoTop10 1}
    3 {UnoRecords $UnoRobot none none $UnoChan ""}
    4 {UnoPlayed $UnoRobot none none $UnoChan ""}
    5 {UnoHighScore $UnoRobot none none $UnoChan ""}
    6 {UnoTopFast $UnoRobot none none $UnoChan ""}
  }
  incr UnoAdNumber
  if {$UnoAdNumber > 6} {set UnoAdNumber 0}
  return
}

#
# Color all cards in hand
#
proc CardColorAll {cplayer} {
  global UnoHand
  set pCard ""
  set ccount 0
  while {[llength $UnoHand($cplayer)] != $ccount} {
    append pCard [CardColor [lindex $UnoHand($cplayer) $ccount]]
    incr ccount
  }
  return $pCard
}

#
# Color a single card
#
proc CardColor {pcard} {
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
proc check_hasuno {cplayer} {
  global UnoHand
  if {[llength $UnoHand($cplayer)] > 1} {return}
  hasuno $cplayer
  return
}

#
# Check for winner
#
proc check_unowin {cplayer ccard} {
  global UnoHand
  if {[llength $UnoHand($cplayer)] > 0} {return 0}
  return 1
}

#
# Show player what cards they have
#
proc showcards {idx pcards} {
  global UnoIDX
  if {[uno_isrobot $idx]} {return}
  unontc [lindex $UnoIDX $idx] "En main : $pcards"
}

#
# Check if this is the robot player
#
proc uno_isrobot {cplayerIDX} {
  global RoundRobin UnoRobot UnoMaxNickLen
  if {[string range [lindex $RoundRobin $cplayerIDX] 0 $UnoMaxNickLen] != $UnoRobot} {return 0}
  return 1
}

# Show played card
proc playcard {who crd nplayer} {
  global mysock
  if {$mysock(debug)==1} {
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
proc playdraw {who crd dplayer nplayer} { ::uno::msg [::msgcat::mc uno_playdraw [::uno::nikclr $who] $crd [::uno::nikclr $dplayer] [::uno::nikclr $nplayer]] }
# Show played wildcard
proc playwild {who chooser} { ::uno::msg [::msgcat::mc uno_playwild [::uno::nikclr $who] [wild] [::uno::nikclr $chooser]] }
# Show played wild draw four
proc playwildfour {who skipper chooser} { ::uno::msg [::msgcat::mc uno_playwildfour [::uno::nikclr $who] [wildf] [::uno::nikclr $skipper] [::uno::nikclr $chooser]] }
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
proc ::uno::hasuno {who} { ::irc::send ":$::uno::nick PRIVMSG $::uno::Chan :\001ACTION [::msgcat::mc uno_hasuno [::uno::nikclr $who]]\001" }


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
  set ::uno::CurrentTime [unixtime]
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
  ::irc::send ":$::uno::nick PRIVMSG $::uno::chan :$what"
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
  if {[uno_isrobot $ThisPlayerIDX]} {return}
  set Idler $ThisPlayer
  set IdlerIDX $ThisPlayerIDX
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

