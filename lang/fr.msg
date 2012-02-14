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
::msgcat::mcset fr startserv "Démarrage des services."
::msgcat::mcset fr loadmodule "Chargement du module %s."
::msgcat::mcset fr loadgame "Chargement du jeu : %s."
::msgcat::mcset fr loadaddon "Chargement de l'addon pour le Master Bot : %s."
::msgcat::mcset fr filenotexist "Impossible de charger %s. Le fichier n'existe pas."
::msgcat::mcset fr loading "Chargement de %s."
::msgcat::mcset fr initlink1 "Initialisation de la liaison étape 1 : Creation du socket vers %s:%s"
::msgcat::mcset fr initssllink1 "Initialisation de la liaison SSL étape 1 : Creation du socket vers %s:%s"
::msgcat::mcset fr sockerror "Erreur lors de l'ouverture du socket : %s"
::msgcat::mcset fr days "jours"
::msgcat::mcset fr hours "heures"
::msgcat::mcset fr minutes "minutes"
::msgcat::mcset fr seconds "secondes"
::msgcat::mcset fr closepls "Fermeture de toutes les partylines"
::msgcat::mcset fr rehashdone "Rehash effectué."
::msgcat::mcset fr botjoin0 "On a tenté de faire partir le robot %s de tous les chans via un join 0."

# Messages for controller
::msgcat::mcset fr cont_netconn "Connexion au réseau."
::msgcat::mcset fr cont_shutdown "Coupure des services démandée par %s."
::msgcat::mcset fr cont_sockclose "Fermeture du socket"
::msgcat::mcset fr cont_rehash "\00310Rehash par %s"
::msgcat::mcset fr cont_send "\00310Envoi d'un raw par %s : %s"
::msgcat::mcset fr cont_source "\00310Source de %s par %s"
::msgcat::mcset fr cont_tcl "\00310TCL\017 Execution par %s de %s"
::msgcat::mcset fr cont_botjoin0 "\002%s\002 a tenté de me faire partir de tous les chans via un join 0."
::msgcat::mcset fr cont_notleaveadminchan0 "Je ne peux pas partir de %s !"
::msgcat::mcset fr cont_notleaveadminchan1 "%s a tenté de me faire partir de %s !"
::msgcat::mcset fr cont_leavechan "%s m'a demandé de partir !"
::msgcat::mcset fr cont_testflood "Test de flood sur IRC N° %3d"
::msgcat::mcset fr cont_whois0 "%s vient d'essayer de whois %s"
::msgcat::mcset fr cont_whois1 "Merci de ne pas whois %s"
::msgcat::mcset fr cont_notachan "Cette commande n'est disponible que sur un salon."
::msgcat::mcset fr cont_nossl "Le module SSL n'est pas activé."
::msgcat::mcset fr cont_dcc "\00310DCC Accès à la partyline demandé par %s"

# Messages for partyline
::msgcat::mcset fr pl_activation "Activation de la PL sur %s:%s."
::msgcat::mcset fr pl_openport "Ouverture du port PL : OK"
::msgcat::mcset fr pl_incconn "Arrivée d'une connexion Partyline."
::msgcat::mcset fr pl_activated "\00304\002PL activée :\017 %s > %d:%s:%d"
::msgcat::mcset fr pl_close "Fermeture du socket PL %s par l'utilisateur %s"
::msgcat::mcset fr pl_help0 "Aide du framework de services UnrealIRCD v%s"
::msgcat::mcset fr pl_help1 "Commandes partyline"
::msgcat::mcset fr pl_help2 "Ferme votre PL ou une PL donnée en paramètre"
::msgcat::mcset fr pl_help3 "Affiche la liste des personnes en PL"
::msgcat::mcset fr pl_help4 "Recharge le service"
::msgcat::mcset fr pl_help5 "Tue le service"
::msgcat::mcset fr pl_help6 "Affiche les informations SSL si celui ci est activé"
::msgcat::mcset fr pl_help7 "Envoie un RAW au réseau IRC"
::msgcat::mcset fr pl_help8 "Source un fichier si il existe"
::msgcat::mcset fr pl_inpl "Présent en PL : %s"
::msgcat::mcset fr pl_inplauth "Présent en PL et authentifié : %s"
::msgcat::mcset fr pl_die "Die par la PL : %s"
::msgcat::mcset fr pl_auth0 "Vous êtes authentifié !!!"
::msgcat::mcset fr pl_auth1 "\00303\002PL Auth :\017 Mot de passe accepté sur %s"
::msgcat::mcset fr pl_auth2 "\00304\002PL Auth :\017 Mauvais mot de passe sur %s"
::msgcat::mcset fr pl_notauth "Vous n'êtes pas authentifié. Merci d'utiliser la commande .pass <password> pour vous authentifier."
::msgcat::mcset fr pl_loaded "Serveur de PartyLine chargé."
::msgcat::mcset fr pl_alreadyload "La PL est déjà chargée !"

# vim: set fenc=utf-8 sw=2 sts=2 ts=2 et filetype=tcl
