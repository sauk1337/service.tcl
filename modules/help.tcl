#####################################################################
# service.tcl - module: help
# help / commands: lists the commands a user can use, grouped by category,
# and "help <command>" shows syntax, description, aliases and access.
# Help texts are partly based on r0t3n's commands.ini (service v5).
#####################################################################

namespace eval service {
	variable helpdb
	array unset helpdb
	# command {category flags syntax description}
	# flags: who can use it (Eggdrop flags, global|channel)
	array set helpdb {
		adduser {Users nm|nm "<nickname> <handle> ?-global|#channel? <level>" "Adds a user with the given handle and access level (owner, master, op, voice, ban). The +x host or *!*ident@host is stored, and the Q account when the user is authed."}
		access {Users nm|nm "<nickname|#handle> ?-global|#channel? ?level?" "Shows or changes a user's access level. Use 'none' or 'clear' to remove the access."}
		deluser {Users nm|nm "<nickname|#handle>" "Removes a user's access on this channel."}
		whois {Users anmovf|anmovf "<nickname|#handle>" "Shows bot account information about a user."}
		whoami {Users anmovf|anmovf "" "Shows your own bot account information."}
		userlist {Users nmo|nmo "?-global?" "Lists the users known on this channel (or all global users)."}
		mytrigger {Users - "?trigger?" "Shows or changes your personal command trigger. Valid: \$ ! ? & * % ^ - + ~"}
		account {Users nm|nm "<nickname|#handle> ?qaccount|-?" "Links a bot user to a QuakeNet (Q) account, so the user is recognised by the account even without +x or a matching host. Without an account it shows the link, '-' removes it."}

		protection {Protection nm|nm "on|off|status|hard on|off" "Channel protection: reverts mode, kick and topic changes by unknown users and kick-bans them. Hard protection also protects against channel operators. Required for takeover protection."}
		takeover {Protection nm|nm "" "Shows the takeover protection settings: mass deop/kick/ban thresholds and the actions taken (Q RECOVER, Q TEMPBAN, Q CHANLEV removal, lockdown, re-op). Configured in service.conf."}
		lockdown {Protection nm|nm "on ?+modes? ?seconds?|off|status" "Locks the channel (default +im) for a time or until 'lockdown off'. Only the modes that were not already set are removed again."}
		enforcemodes {Protection nm|nm "<+-modes> ?key? ?limit?|on|off|status" "Keeps channel modes fixed: any change to an enforced mode is undone, even by ops. Example: enforcemodes +nt-i."}
		bitchmode {Protection nm|nm "on|off|status" "Only users with op/voice access may be opped/voiced."}
		known {Protection nm|nm "on|off|status" "Known-only: kick-bans everyone who is not in the bot's userlist."}
		clonescan {Protection nm|nm "on|off|status|scan ?-list?|set bantime|maxclones|hosttype #n" "Kick-bans hosts with too many clones on join, or scans the channel."}
		flyby {Protection nm|nm "on|off|status" "Bans users who part within 10 seconds of joining."}
		flood {Protection nm|nm "on|off|status|set chan|join|ctcp|massjoin x:y|bantime n" "Anti-flood settings (lines, joins and CTCPs per seconds)."}
		spamscan {Protection nm|nm "on|off|status" "Point-based spam detection (colours, caps, repeats, adverts, floods) with warn, kick and ban."}
		badword {Protection nm|nm "on|off|add|del|list|check|bantime|status ?word?" "Kick-bans users who say a bad word."}
		antiadvertise {Protection nm|nm "on|off|bantime|status" "Kick-bans users who advertise channels, URLs or IPs."}
		badchan {Protection nm|nm "on|off|add|del|list ?#channel?" "Kick-bans users who are in one of the listed bad channels (checked by WHOIS on join)."}
		authban {Protection nm|nm "on|off|add|del|list ?account?" "Kick-bans users authed with one of the listed Q accounts."}

		chanflags {Settings nm|nm "?+-flags?" "Shows or changes several channel features at once (see the README for the letters)."}
		status {Settings nmo|nmo "" "Shows which features are enabled on this channel."}
		autoop {Settings nm|nm "on|off|status" "Ops everyone who joins."}
		autovoice {Settings nm|nm "on|off|status" "Voices everyone who joins."}
		autolimit {Settings nm|nm "on|off|status|#limit" "Keeps the channel limit at users + limit."}
		welcome {Settings nm|nm "on|off|notice on|off|set <skin>|status" "Welcome message on join (:nickname: :channel: :date: :time: :id:)."}
		automsg {Settings nm|nm "on|off|list|set #1-3 <text>|interval #seconds|modes <+-modes>|status" "Repeats up to three messages in the channel."}
		topic {Settings nm|nm "create <skin>|delete|preview|keywords|set|Q on|off|<keyword> <value>" "Topic system with :keywords:. 'topic Q on' sets topics through Q."}
		peak {Settings - "?on|off|reset?" "Shows the channel's user record (peak). Masters can turn tracking on/off or reset it. A new record is announced in the channel (peak(announce) in service.conf)."}
		vip {Settings nm|nm "on|off|add|del|list|set|authbl|mode|skin ?args?" "Gives op/voice to users who are op/voice in partner channels."}

		op {Channel nmo|nmo "?nickname(s)|mask?" "Ops you, the given users, or (masters) everyone matching a mask. Same syntax for deop, voice and devoice."}
		kick {Channel nmo|nmo "<nickname> ?reason?" "Kicks a user."}
		ban {Channel nmo|nmo "<nickname|mask> ?duration? ?reason?" "Kick-bans a user with a bot ban (duration like 30m, 2h, 1d; 0 = permanent)."}
		unban {Channel nmo|nmo "<mask|#id>" "Removes a ban."}
		banlist {Channel nmo|nmo "?-global?" "Lists the bot's bans."}
		baninfo {Channel nmo|nmo "?-global? <#id|mask>" "Shows details of a ban."}
		banclear {Channel nmo|nmo "?all|-global ?all??" "Removes temporary bans (all = also permanent ones)."}
		invite {Channel nmo|nmo "<nickname>" "Invites a user."}
		mode {Channel nmo|nmo "<+-modes> ?args?" "Sets channel modes."}
		say {Channel nmo|nmo "<text>" "Makes the bot say something."}
		saveop {Channel nm|nm "?list|clear?" "Saves the current ops. The list is kept across restarts and is also used to re-op after a takeover."}
		reop {Channel nm|nm "" "Re-ops the saved ops that are on the channel."}

		qban {Q nmo|nmo "<nickname|mask> ?duration? ?reason?" "Asks Q to TEMPBAN a user. Q bans stay even if the bot leaves. Needs the bot to have +o in Q."}
		qpermban {Q nm|nm "<nickname|mask> ?reason?" "Asks Q to PERMBAN a user."}
		qunban {Q nmo|nmo "<mask|#banid>" "Removes a Q ban (BANDEL). See qbanlist for the ids."}
		qbanlist {Q nmo|nmo "" "Shows Q's ban list for the channel."}
		qbanclear {Q nm|nm "" "Removes all Q bans of the channel."}
		qrecover {Q nm|nm "" "Q RECOVER: deops/devoices everyone and clears bans. Needs +m in Q."}
		qdeopall {Q nm|nm "" "Q DEOPALL: deops everyone."}
		qdevoiceall {Q nm|nm "" "Q DEVOICEALL: devoices everyone."}
		qclearchan {Q nm|nm "" "Q CLEARCHAN: removes all channel modes and bans."}
		qchanflags {Q nm|nm "?+-flags?" "Shows or changes Q's channel flags."}
		qchanmode {Q nm|nm "?+-modes|none?" "Shows or changes the modes Q enforces."}
		qautolimit {Q nm|nm "?limit?" "Shows or changes Q's autolimit."}
		qwelcome {Q nm|nm "?message|none?" "Shows or changes Q's welcome message."}
		qsettopic {Q nm|nm "<topic>" "Sets the topic through Q."}
		qop {Q nmo|nmo "?nickname?" "Asks Q to op you or someone else."}
		qvoice {Q nmo|nmo "?nickname?" "Asks Q to voice you or someone else."}
		qinvite {Q nmo|nmo "" "Asks Q to invite you."}
		chanlev {Q nm|nm "?nickname|#account? ?+-flags?" "Shows or changes Q's chanlev for the channel or for a user."}
		auth {Q nm|nm "" "Authenticates the bot with Q (CHALLENGEAUTH) using the account in service.conf."}

		addchan {Admin nm "<#channel>" "Adds a channel to the bot."}
		delchan {Admin nm "<#channel>" "Removes a channel from the bot."}
		channels {Admin nm "?-list?" "Lists the bot's channels."}
		hop {Admin nm "<#channel>" "Makes the bot part and rejoin a channel."}
		gban {Admin nm "<nickname|mask> ?duration? ?reason?" "Global ban on all channels."}
		gunban {Admin nm "<mask|#id>" "Removes a global ban."}
		spam {Admin nm "<message>" "Broadcasts a message to all channels except the home channels."}
		update {Admin n "?check|apply|status?" "Checks GitHub for a new release and installs it (owners only). Files are verified with SHA-256 and backed up before the update."}
		version {General - "" "Shows the script version."}
		help {General - "?command?" "Lists your commands, or shows help for one command."}
	}
}

# Primary command name for a name or alias, or "" when unknown.
proc service::help_primary {name} {
	set name [string tolower $name]
	if {![info exists ::service::cmdmap($name)]} { return "" }
	set procname $::service::cmdmap($name)
	set primary [string range $procname [string length "service::cmd_"] end]
	if {$primary eq "deop" || $primary eq "voice" || $primary eq "devoice"} { set primary op }
	return $primary
}

proc service::help_aliases {name} {
	set procname $::service::cmdmap($name)
	set aliases [list]
	foreach {n p} [array get ::service::cmdmap] {
		if {$p eq $procname && $n ne $name} { lappend aliases $n }
	}
	return [lsort $aliases]
}

proc service::help_canuse {handle channel flags} {
	return [expr {$flags eq "-" || [matchattr $handle $flags $channel]}]
}

proc service::cmd_help {nickname hostname handle channel text lastbind command} {
	variable helpdb
	service::track $handle "$channel ${lastbind}$command $text"
	set trig [expr {[string index $lastbind end] eq " " ? $lastbind : [getuser $handle XTRA mytrigger]}]
	set topic [string trimleft [lindex [split $text] 0] $service::triggers]
	if {$topic eq ""} {
		array set bycat {}
		foreach name [lsort [array names helpdb]] {
			lassign $helpdb($name) cat flags
			if {![info exists ::service::cmdmap($name)]} { continue }
			if {[service::help_canuse $handle $channel $flags]} {
				lappend bycat($cat) $name
			}
		}
		putserv "NOTICE $nickname :Your commands on $channel (trigger: $trig) - '${trig}help <command>' for details:"
		foreach cat {Users Protection Settings Channel Q Admin General} {
			if {[info exists bycat($cat)]} {
				putserv "NOTICE $nickname :\002$cat:\002 [join $bycat($cat) ", "]"
			}
		}
		return
	}
	set name [string tolower $topic]
	set primary [service::help_primary $name]
	if {$primary eq "" || ![info exists helpdb($primary)]} {
		putserv "NOTICE $nickname :No help for '$topic'. Type ${trig}help for your commands."
		return
	}
	lassign $helpdb($primary) cat flags syntax description
	set aliases [service::help_aliases $name]
	set who [expr {$flags eq "-" ? "everyone" : $flags}]
	putserv "NOTICE $nickname :\002${trig}$name\002 $syntax"
	putserv "NOTICE $nickname :$description"
	putserv "NOTICE $nickname :Access: $who[expr {[llength $aliases] ? " - Aliases: [join $aliases ", "]" : ""}][expr {[service::help_canuse $handle $channel $flags] ? "" : " - (you can't use this command here)"}]"
}
service::register {help commands} service::cmd_help
