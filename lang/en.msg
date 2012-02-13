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
# Copyright (C) 2012 Damien Lesgourgues
# Author(s): Damien Lesgourgues
#
##############################################################################

# Messages for base
::msgcat::mcset en startserv "Starting service."
::msgcat::mcset en loadmodule "Loading module %s."
::msgcat::mcset en loadgame "Loading game : %s."
::msgcat::mcset en loadaddon "Loadding addon for Master Bot : %s."
::msgcat::mcset en filenotexist "Impossible to load %s. File doesn't exist."
::msgcat::mcset en loading "Loading %s."
::msgcat::mcset en initlink1 "Link initialisation step 1 : Creating socket to %s:%s"
::msgcat::mcset en sockerror "Error during opening of socket : %s"
::msgcat::mcset en days "days"
::msgcat::mcset en hours "hours"
::msgcat::mcset en minutes "minutes"
::msgcat::mcset en seconds "seconds"
::msgcat::mcset en closepls "Closing of all partylines"
::msgcat::mcset en rehashdone "Rehash done."
::msgcat::mcset en botjoin0 "Someone try to make %s left all channels via a join 0."

# Messages for controller
::msgcat::mcset en cont_netconn "Network connect."
::msgcat::mcset en cont_shutdown "Shutdown of services asked by %s."
::msgcat::mcset en cont_sockclose "Closing socket"
::msgcat::mcset en cont_rehash "\00310Rehash by %s"
::msgcat::mcset en cont_errorcmd "\00310Print error by %s"
::msgcat::mcset en cont_send "\00310IRC send by %s"
::msgcat::mcset en cont_source "\00310Source of %s by %s"
::msgcat::mcset en cont_tcl "\00310TCL\017 Execution by %s of %s"
::msgcat::mcset en cont_botjoin0 "\002%s\002 try to make me leave all channels via a /join 0."
::msgcat::mcset en cont_notleaveadminchan0 "Je ne peux pas partir de %s !"
::msgcat::mcset en cont_notleaveadminchan1 "%s tried to make me leave of channel %s !"
::msgcat::mcset en cont_leavechan "%s ask me to leave !"
::msgcat::mcset en cont_testflood "Flood test on IRC N° %3d"
::msgcat::mcset en cont_whois0 "%s has try to whois %s"
::msgcat::mcset en cont_whois1 "Please don't whois %s"
::msgcat::mcset en cont_notachan "This command is only available on a channel."

# Messages for partyline
::msgcat::mcset en pl_activation "Activation of partyline on %s:%s."
::msgcat::mcset en pl_openport "Opening of partyline port : OK"
::msgcat::mcset en pl_incconn "Connexion incoming on partyline."
::msgcat::mcset en pl_activated "\00304\002PL activated :\002\003 %s > %d:%s:%d"
::msgcat::mcset en pl_close "Closing of partyline socket %s by user %s"
::msgcat::mcset en pl_help0 "Help of UnrealIRCD Service Framework v%s"
::msgcat::mcset en pl_help1 "Partyline commands"
::msgcat::mcset en pl_help2 "Close your partyline or a given partyline"
::msgcat::mcset en pl_help3 "Print list of users on partyline"
::msgcat::mcset en pl_help4 "Reload the service"
::msgcat::mcset en pl_help5 "Kill the service"
::msgcat::mcset en pl_inpl "Connected on PL : %s"
::msgcat::mcset en pl_inplauth "Connected and authentified on PL : %s"
::msgcat::mcset en pl_rehash "Rehash by partyline : %s"
::msgcat::mcset en pl_die "Die by partyline : %s"
::msgcat::mcset en pl_auth0 "You are authentified !!!"
::msgcat::mcset en pl_auth1 "\00303\002PL Auth :\017 Password accepted on %s"
::msgcat::mcset en pl_auth2 "\00304\002PL Auth :\017 Password refused on %s"
::msgcat::mcset en pl_nouth "You are not authentified. Please use .pass <password> to authentify yourself."
::msgcat::mcset en pl_loaded "PartyLine server loaded."
::msgcat::mcset en pl_alreadyload "PartyLine is already loaded !"

# vim: set fenc=utf-8 sw=2 sts=2 ts=2 et filetype=tcl
