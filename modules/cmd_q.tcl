#####################################################################
# service.tcl - module: cmd_q
# Commands: Q (QuakeNet): chanlev, auth, account and the q* commands that
# act through Q (bans, recover, chanflags, chanmode, autolimit...).
#####################################################################

# chanlev
proc service::cmd_chanlev {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm|nm $channel]} {
		puthelp "NOTICE $nickname :You have no access to this command."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	set who [lindex [split $text] 0]
	set flags [lindex [split $text] 1]
	if {$flags == ""} {
		# no change: let Q list the chanlev (whole channel or one user)
		service::qsend [string trim "CHANLEV $channel $who"] $nickname
		putserv "NOTICE $nickname :Asked Q for the chanlev of [expr {$who eq "" ? $channel : $who}]... (to change: ${lastbind}$command <nickname|#authname> <+-flags>)"
	} elseif {[string equal -nocase $botnick $who]} {
		putserv "NOTICE $nickname :ERROR: You can't modify my own chanlev!"
	} elseif {![regexp -nocase -- {\+|\-} $flags]} {
		putserv "NOTICE $nickname :Invalid flags format. You need to indicate a + and/or - sign."
	} elseif {![onchan Q $channel]} {
		putserv "NOTICE $nickname :ERROR: Q is not present on $channel."
	} else {
		service::qsend "CHANLEV $channel $who $flags" $nickname
		putserv "NOTICE $nickname :Done."
	}
}
service::register chanlev service::cmd_chanlev

# auth
proc service::cmd_auth {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm|nm $channel]} {
		putserv "NOTICE $nickname :You dont have access to this command!"
		return
	}
	service::track $handle "${lastbind}$command"
	if {[string match -nocase *users.quakenet.org $::botname]} {
		putserv "NOTICE $nickname :I'm already authed!"
	} elseif {![string equal -nocase [join [lrange [split [lindex [split $::server :] 0] .] end-1 end] .] quakenet.org]} {
		putserv "NOTICE $nickname :Error: network/server does not end in 'quakenet.org'..."
	} elseif {![service::qauth]} {
		putserv "NOTICE $nickname :Error: no Q account configured (set qauth(user) and qauth(pass) in service.conf)."
	} else {
		putserv "NOTICE $nickname :Sent auth to Q... this may take a few seconds depending on queue times."
	}
}
service::register auth service::cmd_auth

# --- commands that act through Q --------------------------------------------
# The bot needs enough Q access on the channel (chanlev +o for bans/op,
# +m for recover/chanflags/chanmode/...). Q's answers are relayed to the user.

proc service::qcmd_run {nickname handle channel text lastbind command flags qcmd syntax} {
	if {![matchattr $handle $flags $channel]} {
		putserv "NOTICE $nickname :You have no access to this command."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	if {[string match "*<*" $syntax] && [string trim $text] eq ""} {
		putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command $syntax"
		return
	}
	service::qsend [string trim "$qcmd $channel $text"] $nickname
	putserv "NOTICE $nickname :Sent to Q: [string trim "$qcmd $channel $text"]"
}

# names  required-flags  Q-command  syntax
foreach {names flags qcmd syntax} {
	{qunban qbandel}  nmo|nmo BANDEL     "<hostmask|#banid>"
	{qbanlist}        nmo|nmo BANLIST    ""
	{qbanclear}       nm|nm   BANCLEAR   ""
	{qrecover}        nm|nm   RECOVER    ""
	{qdeopall}        nm|nm   DEOPALL    ""
	{qdevoiceall}     nm|nm   DEVOICEALL ""
	{qclearchan}      nm|nm   CLEARCHAN  ""
	{qchanflags}      nm|nm   CHANFLAGS  "?+-flags?"
	{qchanmode}       nm|nm   CHANMODE   "?+-modes|none?"
	{qautolimit}      nm|nm   AUTOLIMIT  "?limit?"
	{qwelcome}        nm|nm   WELCOME    "?message|none?"
	{qsettopic}       nm|nm   SETTOPIC   "<topic>"
	{qop}             nmo|nmo OP         "?nickname?"
	{qvoice}          nmo|nmo VOICE      "?nickname?"
	{qinvite}         nmo|nmo INVITE     ""
} {
	set procname service::cmd_[lindex $names 0]
	proc $procname {nickname hostname handle channel text lastbind command} "service::qcmd_run \$nickname \$handle \$channel \$text \$lastbind \$command [list $flags $qcmd $syntax]"
	service::register $names $procname
}
unset -nocomplain names flags qcmd syntax procname

# Resolves a nickname (on the channel) or a hostmask to a ban mask.
# Returns "" (and tells the user why) when it can't be banned.
proc service::qban_target {nickname handle channel target} {
	if {[string match "*!*@*" $target]} {
		if {[string match {\*!\*@\*} $target] || [regexp {^[*?!@.]+$} $target]} {
			putserv "NOTICE $nickname :Invalid banmask '$target'."
			return ""
		}
		set mask $target
		set hand [service::host2hand $target]
	} elseif {[onchan $target $channel]} {
		if {[isbotnick $target]} {
			putserv "NOTICE $nickname :You can't ban me!"
			return ""
		}
		set mask [service::banmask [getchanhost $target $channel]]
		set hand [service::resolve $target [nick2hand $target $channel]]
	} else {
		putserv "NOTICE $nickname :$target isn't on $channel (use a nick!user@host mask instead)."
		return ""
	}
	if {[validuser $hand]} {
		if {([matchattr $hand nm] && ![matchattr $handle n]) || [matchattr $hand N]} {
			putserv "NOTICE $nickname :You can't ban a protected user ($hand)."
			return ""
		}
		if {[matchattr $hand |n $channel] && ![matchattr $handle n|n $channel]} {
			putserv "NOTICE $nickname :You don't have enough access to ban a channel owner."
			return ""
		}
		if {[matchattr $hand |m $channel] && ![matchattr $handle nm|n $channel]} {
			putserv "NOTICE $nickname :You don't have enough access to ban a channel master."
			return ""
		}
	}
	return $mask
}

# qban <nick|mask> ?duration? ?reason?  - Q TEMPBAN (survives the bot leaving)
proc service::cmd_qban {nickname hostname handle channel text lastbind command} {
	if {![matchattr $handle nmo|nmo $channel]} {
		putserv "NOTICE $nickname :You have no access to this command."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	set words [split $text]
	if {[set target [lindex $words 0]] eq ""} {
		putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command <nickname|hostmask> ?duration? ?reason? (duration like 30m, 2h, 1d, 1w - default [service::cfg qcmd bantime 1h])"
		return
	}
	set duration [lindex $words 1]
	if {[regexp {^([0-9]+[smhdwy])+$} $duration]} {
		set reason [join [lrange $words 2 end]]
	} else {
		set duration [service::cfg qcmd bantime 1h]
		set reason [join [lrange $words 1 end]]
	}
	if {[set mask [service::qban_target $nickname $handle $channel $target]] eq ""} { return }
	if {$reason eq ""} { set reason "Banned by $nickname" }
	service::qsend "TEMPBAN $channel $mask $duration $reason" $nickname
	putserv "NOTICE $nickname :Asked Q to ban $mask on $channel for $duration."
}
service::register {qban qtempban} service::cmd_qban

# qpermban <nick|mask> ?reason?  - Q PERMBAN
proc service::cmd_qpermban {nickname hostname handle channel text lastbind command} {
	if {![matchattr $handle nm|nm $channel]} {
		putserv "NOTICE $nickname :You have no access to this command."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	set words [split $text]
	if {[set target [lindex $words 0]] eq ""} {
		putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command <nickname|hostmask> ?reason?"
		return
	}
	if {[set mask [service::qban_target $nickname $handle $channel $target]] eq ""} { return }
	set reason [join [lrange $words 1 end]]
	if {$reason eq ""} { set reason "Banned by $nickname" }
	service::qsend "PERMBAN $channel $mask $reason" $nickname
	putserv "NOTICE $nickname :Asked Q to permanently ban $mask on $channel."
}
service::register qpermban service::cmd_qpermban

# account <nickname|#handle> ?qaccount|-?
# Links a bot user to a QuakeNet account: the user is then recognised by
# the account (even without +x or a matching hostmask).
proc service::cmd_account {nickname hostname handle channel text lastbind command} {
	if {![matchattr $handle nm|nm $channel]} {
		putserv "NOTICE $nickname :You have no access to this command."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	set words [split $text]
	set who [lindex $words 0]
	if {$who eq ""} {
		putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command <nickname|#handle> ?qaccount|-? (without account: show; '-' removes it)"
		return
	}
	if {[string index $who 0] eq "#"} {
		set hand [string range $who 1 end]
	} else {
		set hand [service::resolve $who [nick2hand $who]]
	}
	if {![validuser $hand]} {
		putserv "NOTICE $nickname :'$who' is not known to my database."
		return
	}
	if {![matchattr $handle nm] && [matchattr $hand nm|nm $channel] && ![matchattr $handle |n $channel]} {
		putserv "NOTICE $nickname :You don't have enough access to change the account of '$hand'."
		return
	}
	set acct [lindex $words 1]
	if {$acct eq ""} {
		set current [getuser $hand XTRA account]
		set online [expr {[string index $who 0] ne "#" ? [service::account $who] : ""}]
		putserv "NOTICE $nickname :#$hand is linked to Q account: [expr {$current eq "" ? "none" : $current}][expr {$online ne "" ? " - $who is authed as $online" : ""}]."
		return
	}
	if {$acct eq "-"} {
		setuser $hand XTRA account ""
		service::acct_rebuild
		putserv "NOTICE $nickname :Removed the Q account link of #$hand."
		return
	}
	set acct [string trimleft $acct #]
	if {![regexp {^[A-Za-z0-9\[\]\`^{}|_-]{1,15}$} $acct]} {
		putserv "NOTICE $nickname :Invalid Q account name '$acct'."
		return
	}
	variable acct2hand
	if {[info exists acct2hand([string tolower $acct])] && $acct2hand([string tolower $acct]) ne $hand} {
		putserv "NOTICE $nickname :Q account '$acct' is already linked to #$acct2hand([string tolower $acct])."
		return
	}
	setuser $hand XTRA account $acct
	service::acct_rebuild
	putserv "NOTICE $nickname :#$hand is now linked to Q account '$acct'."
}
service::register account service::cmd_account
