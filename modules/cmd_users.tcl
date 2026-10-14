#####################################################################
# service.tcl - module: cmd_users
# Commands: user management (adduser, access, deluser, whois, whoami,
# userlist, mytrigger).
#####################################################################

namespace eval service {
	# WHOIS answers for adduser's Q account lookup
	bind raw - {330} [namespace current]::acctlookup_raw
	bind raw - {318} [namespace current]::acctlookup_raw
}

# Adds the user's Q auth host (*!*@<account>.users.quakenet.org) besides the
# host they were added with. Users without +x: the account is looked up
# with a WHOIS (330 "is authed as") and added when the answer arrives.
proc service::adduser_authhost {hand who adder} {
	if {[set acct [service::account $who]] ne ""} {
		if {[set mask [service::add_authhost $hand $acct]] ne ""} {
			putserv "NOTICE $adder :Also added Q auth host $mask to $hand."
		}
		return
	}
	set ::service::acctlookup([string tolower $who]) [list $hand $adder]
	puthelp "WHOIS $who"
}

proc service::acctlookup_raw {from raw arg} {
	set nick [string tolower [lindex [split $arg] 1]]
	if {![info exists ::service::acctlookup($nick)]} { return 0 }
	lassign $::service::acctlookup($nick) hand adder
	unset ::service::acctlookup($nick)
	if {$raw eq "330"} {
		if {[set mask [service::add_authhost $hand [lindex [split $arg] 2]]] ne ""} {
			putserv "NOTICE $adder :Also added Q auth host $mask to $hand."
		}
	} else {
		# end of WHOIS without a 330 line: not authed with Q
		putserv "NOTICE $adder :[lindex [split $arg] 1] is not authed with Q: only the hostmask was added to $hand."
	}
	return 0
}

# adduser, add
proc service::cmd_adduser {nickname hostname handle channel text lastbind command} {
	global botnick
	# SYNTAX: adduser nickname handle ?-global|#channel? <level>
	if {![matchattr $handle nm|nm $channel]} {
		putserv "NOTICE $nickname :Error: Only channel owners/masters can add users to $channel."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	set who [lindex [split $text] 0]
	set hand [lindex [split $text] 1]
	set where [lindex [split $text] 2]
	if {[llength [split $text]] < 3} {
		putserv "NOTICE $nickname :SYNTAX: ${lastbind}${command} <nickname> <handle> ?-global|#channel? <level>."
		return
	}
	if {[string equal -nocase "-global" $where]} {
		set level [string tolower [lindex [split $text] 3]]
		if {![onchan $who]} {
			putserv "NOTICE $nickname :ERROR: User '$who' is not on any of my channels."; return
		} elseif {[validuser [nick2hand $who]]} {
			putserv "NOTICE $nickname :ERROR: User '$who' is already added as '[nick2hand $who]' - please use the ACCESS command to further modify access."; return
		} elseif {[string length $hand] < 2 || [string length $hand] > 9} {
			putserv "NOTICE $nickname :ERROR: Handle length must be between 2 to 9 characters long."; return
		} elseif {[validuser $hand]} {
			putserv "NOTICE $nickname :ERROR: Handle '$hand' already exists - use the ACCESS command to change its access."; return
		} elseif {![info exists service::global_user_levels($level)]} {
			putserv "NOTICE $nickname :Invalid userlevel '$level' specified. (Valid userlevels: [join [array names service::global_user_levels] ", "])"; return
		} else {
			if {[getchanhost $who] == ""} {
				putserv "NOTICE $nickname :ERROR: Could not grab hostname for $who - carn't proceed."
				return
			}
			set levels $service::global_user_levels($level)
			if {[string match -nocase *users.quakenet.org [set host *!*[string trimleft [getchanhost $who] ~]]]} {
				set host *!*@[lindex [split $host @] 1]
			}
			set mf [lindex [split $levels] 0]; # flags required
			set af [lindex [split $levels] 1]; # flags provided
			if {![matchattr $handle $mf]} {
				putserv "NOTICE $nickname :ERROR: You do not have the required priviledges to add '$who' (#$hand) as 'global $level'."
			} else {
				adduser $hand $host
				service::adduser_authhost $hand $who $nickname
				chattr $hand $af
				setuser $hand XTRA mytrigger "$service::trigger"
				setuser $hand XTRA mytriggerset "[clock seconds]"
				channel set $service::adminchan service_userid "[set userid [expr {[channel get $service::adminchan service_userid]+1}]]"
				setuser $hand XTRA userid "$userid"
				setuser $hand XTRA email "N/A"
				setuser $hand XTRA loggedin "1"
				setuser $hand XTRA lastlogin "[clock seconds]"
				setuser $hand XTRA lasthost "[string trimleft [getchanhost $who] ~]"
				setuser $hand XTRA cmdcount "0"
				setuser $hand XTRA lastcmd "N/A"
				putserv "NOTICE $nickname :\002$who\002 ($hand) added as \002global $level\002."
				putserv "NOTICE $who :\002$nickname ($handle)\002 added you as \002global $level\002."
				putserv "NOTICE $who :For security reasons, please type: /msg $::botnick password <password>. Your default mytrigger is set to: $service::trigger. To find out my commands, please type ${service::trigger}commands or $::botnick commands."
				if {$level == "ban"} {
					set kickmsg $service::kickmsg(gban)
					channel set $service::adminchan service_gkid [set id [expr {[channel get $service::adminchan service_gkid] + 1}]]
					set kickmsg [string map [list :adminchan: "$service::adminchan"] $kickmsg]
					set kickmsg [string map [list :id: "$id"] $kickmsg]
					set kickmsg [string map [list :reason: "Global Banned"] $kickmsg]
					newban $host $handle "$kickmsg" 0
				}
			}
		}
		return
	} elseif {[string index $where 0] == "#"} {
		if {![validchan [set chan $where]]} {
			putserv "NOTICE $nickname :ERROR: Channel '$chan' is unknown to me."
			return
		} else {
			set level [string tolower [lindex [split $text] 3]]
		}
	} else {
		set chan $channel
		set level [string tolower [lindex [split $text] 2]]
	}
	if {![onchan $who $chan]} {
		putserv "NOTICE $nickname :ERROR: User '$who' is not on '$chan'."
	} elseif {[validuser [nick2hand $who $chan]]} {
		putserv "NOTICE $nickname :ERROR: User '$who' is already added as '[nick2hand $who]' - please use the ACCESS command to further modify access."
	} elseif {[string length $hand] < 2 || [string length $hand] > 9} {
		putserv "NOTICE $nickname :ERROR: Handle length must be between 2 to 9 characters long."
	} elseif {[validuser $hand]} {
		putserv "NOTICE $nickname :ERROR: Handle '$hand' already exists - use the ACCESS command to change its access."
	} elseif {![info exists service::channel_user_levels($level)]} {
		putserv "NOTICE $nickname :Invalid userlevel '$level' specified. (Valid userlevels: [join [array names service::channel_user_levels] ", "])"
	} else {
		set levels $service::channel_user_levels($level)
		if {[string match -nocase *users.quakenet.org [set host *!*[string trimleft [getchanhost $who $chan] ~]]]} {
			set host *!*@[lindex [split $host @] 1]
		}
		set mf [lindex [split $levels] 0]; # flags required
		set af [lindex [split $levels] 1]; # flags provided
		if {![matchattr $handle ${mf}|${mf} $chan]} {
			putserv "NOTICE $nickname :ERROR: You do not have the required priviledges to add '$who' (#$hand) as '$chan $level'."
		} else {
			adduser $hand $host
			service::adduser_authhost $hand $who $nickname
			chattr $hand |$af $chan
			setuser $hand XTRA mytrigger "$service::trigger"
			setuser $hand XTRA mytriggerset "[clock seconds]"
			channel set $service::adminchan service_userid "[set userid [expr {[channel get $service::adminchan service_userid]+1}]]"
			setuser $hand XTRA userid "$userid"
			setuser $hand XTRA email "N/A"
			setuser $hand XTRA loggedin "1"
			setuser $hand XTRA lastlogin "[clock seconds]"
			setuser $hand XTRA lasthost "[string trimleft [getchanhost $who $channel] ~]"
			setuser $hand XTRA cmdcount "0"
			setuser $hand XTRA lastcmd "N/A"
			putserv "NOTICE $nickname :\002$who\002 ($hand) added as \002$chan $level\002."
			putserv "NOTICE $who :\002$nickname ($handle)\002 added you as \002$chan $level\002."
			putserv "NOTICE $who :For security reasons, please type: /msg $::botnick password <password>. Your default mytrigger is set to: $service::trigger. To find out my commands, please type ${service::trigger}commands or $::botnick commands."
			if {$level == "ban"} {
				newchanban $chan $host $handle "$service::kickmsg(defaultban)" 0
			} elseif {![isop $who $chan] && [botisop $chan] && [matchattr $hand |nmo $chan]} {
				pushmode $chan +o $who
			} elseif {![isvoice $who $chan] && [botisop $chan] && [matchattr $hand |vf $chan]} {
				pushmode $chan +v $who
			}
		}
	}
}
service::register {adduser add} service::cmd_adduser

# access
proc service::cmd_access {nickname hostname handle channel text lastbind command} {
	global botnick
	# SYNTAX: %access <nickname|#handle> ?-global|#channel? ?level?
	service::track $handle "$channel ${lastbind}$command $text"
	if {[llength [split $text]] < 1} {
		putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command <nickname|#handle> ?-global|#channel? ?level?"
		return
	}
	set who [lindex [split $text] 0]
	if {[string index $who 0] == "#"} {
		if {![validuser [set hand [string range $who 1 end]]]} {
			putserv "NOTICE $nickname :ERROR: Handle '$hand' does not exist in my database."
			return
		}
	} elseif {[set hand [nick2hand $who]] == "*"} {
		putserv "NOTICE $nickname :ERROR: Nickname '$who' does not match any of my users."
		return
	}
	set where [lindex [split $text] 1]
	if {[string equal -nocase  "-global" $where]} {
		set level [string tolower [lindex [split $text] 2]]
		set cl [service::accesslevel $hand]; # current level
		switch -exact -- $cl {
			0 {set before "Global Nothing"}
			1 {set before "Global Ban"}
			2 {set before "Global Voice"}
			3 {set before "Global Operator"}
			4 {set before "Global Master"}
			5 {set before "Global Owner"}
			6 {set before "Network Service"}
			7 {set before "Bot Developer"}
			8 {set before "Bot Administrator"}
		}
		if {$level == ""} {
			putserv "NOTICE $nickname :Global userlevel for '$who' is currently '$before'."
			return
		}
		if {![info exists service::global_user_levels($level)]} {
			putserv "NOTICE $nickname :Invalid userlevel '$level' specified. (Valid userlevels: [join [array names service::global_user_levels] ", "])"
		} else {
			set levels $service::global_user_levels($level)
			set mf [lindex [split $levels] 0]; # flags required
			set af [lindex [split $levels] 1]; # flags provided
			if {[matchattr $hand $af]} {
				putserv "NOTICE $nickname :ERROR: User '$who' is already 'global $level'."
			} elseif {([matchattr $hand AD] && ![matchattr $handle A]) || ([matchattr $hand n] && ![matchattr $handle AD|] && ![matchattr $handle n]) || ([matchattr $hand m] && ![matchattr $handle ADn])} {
				putserv "NOTICE $nickname :ERROR: You can't change the access of a user with the same or higher global level ('$before')."
			} elseif {![matchattr $handle $mf]} {
				putserv "NOTICE $nickname :ERROR: You do not have the required priviledges to modify '$who' to 'global $level'."
			} else {
				chattr $hand $af
				if {[string equal -nocase "clear" $level] || [string equal -nocase "none" $level]} { set level "nothing" }
				set type [expr {[service::accesslevel $hand] > $cl ? "Upgraded" : "Downgraded"}]
				if {[string equal -nocase "ban" $level]} {
					set kickmsg $service::kickmsg(gban)
					channel set $service::adminchan service_gkid [set id [expr {[channel get $service::adminchan service_gkid] + 1}]]
					set kickmsg [string map [list :adminchan: "$service::adminchan"] $kickmsg]
					set kickmsg [string map [list :id: "$id"] $kickmsg]
					set kickmsg [string map [list :reason: "Global Banned"] $kickmsg]
					foreach host [getuser $hand HOSTS] {
						if {$host == "" || $host == "*!*@*" || $host == "*!*@" || [string match -nocase "-telnet!*@*" $host]} { continue }
						newban $host $handle "$kickmsg" 0
					}
				}
				#putserv "NOTICE $nickname :Global Access level for '#$hand' has been \002$type\002 from \002$before\002 to \002Global Ban\002."
				putserv "NOTICE $nickname :$type user access for '$who' from '$before' to 'global $level'."
			}
		}
		return
	} elseif {[string index $where 0] == "#"} {
		if {![validchan $where]} {
			putserv "NOTICE $nickname :ERROR: Invalid channel '$where' specified."
			return
		} else {
			set chan $where
			set level [string tolower [lindex [split $text] 2]]
		}
	} else {
		set chan $channel
		set level [string tolower [lindex [split $text] 1]]
	}
	set cl [service::accesslevel $hand $chan]; # current level
	switch -exact -- $cl {
		0 {set before "unknown"}
		1 {set before "banned"}
		2 {set before "voice"}
		3 {set before "operator"}
		4 {set before "master"}
		5 {set before "owner"}
	}
	if {$level == ""} {
		putserv "NOTICE $nickname :Userlevel for '$who' is currently '$before' on '$chan'."
	} elseif {![info exists service::channel_user_levels($level)]} {
		putserv "NOTICE $nickname :Invalid userlevel '$level' specified. (Valid userlevels: [join [array names service::channel_user_levels] ", "])"
	} else {
		set levels $service::channel_user_levels($level)
		set mf [lindex [split $levels] 0]; # flags required
		set af [lindex [split $levels] 1]; # flags provided
		#if {[matchattr $hand |$cf $chan]} {
		#	putserv "NOTICE $nickname :ERROR: User '$who' is already '$level' on '$chan'."
		#} else
		set mylevel [service::accesslevel $handle $chan]
		if {![matchattr $handle ADnm] && $hand ne $handle && ($cl > $mylevel || ($cl == $mylevel && $mylevel < 5))} {
			putserv "NOTICE $nickname :ERROR: You can't change the access of '$who' ('$before' on '$chan'): same or higher level than yours."
		} elseif {![matchattr $handle ${mf}|${mf} $chan]} {
			putserv "NOTICE $nickname :ERROR: You do not have the required priviledges to modify '$who' to '$level' on '$chan'."
		} else {
			chattr $hand |$af $chan
			if {[string equal -nocase "clear" $level] || [string equal -nocase "none" $level]} { set level "nothing" }
			#if {[service::accesslevel $hand] == $cl} {
			#    set type "Set"
			#} else {
			#    set type [expr {[service::accesslevel $hand] > $cl ? "Upgraded" : "Downgraded"}]
			#}
			set type [expr {[service::accesslevel $hand] == $cl ? "Reset" : [expr {[service::accesslevel $hand] > $cl ? "Upgraded" : "Downgraded"}] }]
			if {[string equal -nocase "ban" $level]} {
				foreach host [getuser $hand HOSTS] {
					if {$host == "" || $host == "*!*@*" || $host == "*!*@" || [string match -nocase "-telnet!*@*" $host]} { continue }
					newchanban $chan $host $handle "$service::kickmsg(defaultban)" 0
				}
			}
			#putserv "NOTICE $nickname :Access level for '#$hand' has been \002$type\002 from \002$before\002 to \002Channel Ban\002."
			putserv "NOTICE $nickname :$type user access for '$who' from '$before' to '$level' on '$chan'."
		}
	}
}
service::register access service::cmd_access

# deluser
proc service::cmd_deluser {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm|nm $channel]} {
		puthelp "NOTICE $nickname :Only channel owners/masters can remove users from $channel."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	set who [lindex [split $text] 0]
	if {$who == ""} {
		putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command nickname|#handle."
	} else {
		if {[string index $who 0] == "#"} {
			set who [string trimleft $who #]
			if {![validuser $who]} {
				putserv "NOTICE $nickname :Invalid handle '\002#$who\002'."
			} elseif {![matchattr $who |amnovf $channel]} {
				putserv "NOTICE $nickname :\002#$who\002 is not known to \002$channel\002."
			} elseif {[matchattr $who |nm $channel] && ![matchattr $handle nm|n $channel]} {
				putserv "NOTICE $nickname :You don't have enough access to remove a channel owner/master."
			} else {
				set flags [lindex [split [chattr $who $channel] |] 1]
				chattr $who |-$flags $channel
				set status "??"
				if {[string match *n* $flags]} {
					set status "Owner"
				} elseif {[string match *m* $flags]} {
					set status "Master"
				} elseif {[string match *o* $flags]} {
					set status "Operator"
				} elseif {[string match *v* $flags] || [string match *f* $flags]} {
					set status "Friend/Voice"
				} elseif {[string match *B* $flags]} {
					set status "Ban"
				}
				putserv "NOTICE $nickname :'\002#$who\002' deleted as '\002$channel $status\002'."
			}
		} elseif {![onchan $who $channel]} {
			putserv "NOTICE $nickname :$who isn't on $channel."
		} elseif {![validuser [nick2hand $who]]} {
			putserv "NOTICE $nickname :\002$who\002 is not known to my database."
		} elseif {![matchattr [nick2hand $who] |amnovf $channel]} {
			putserv "NOTICE $nickname :\002$who\002 is not known to \002$channel\002."
		} elseif {[matchattr [set hand [nick2hand $who]] |nm $channel] && ![matchattr $handle nm|n $channel]} {
			putserv "NOTICE $nickname :You don't have enough access to remove a channel owner/master."
		} else {
			set flags [lindex [split [chattr $hand $channel] |] 1]
			chattr $hand |-$flags $channel
			set status "??"
			if {[string match *n* $flags]} {
				set status "Owner"
			} elseif {[string match *m* $flags]} {
				set status "Master"
			} elseif {[string match *o* $flags]} {
				set status "Operator"
			} elseif {[string match *v* $flags] || [string match *f* $flags]} {
				set status "Friend/Voice"
			} elseif {[string match *B* $flags]} {
				set status "Ban"
			}
			putserv "NOTICE $nickname :'\002$who\002' deleted as '\002$channel $status\002'."
		}
	}
}
service::register deluser service::cmd_deluser

# whois
proc service::cmd_whois {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle anmovf|anmovf $channel]} {
		puthelp "NOTICE $nickname :You are not known to me and so you can't whois my users."
		return
	}
	if {![string equal -nocase $nickname [lindex [split $text] 0]] || ![string equal -nocase #$handle [lindex [split $text] 0]]} {
		setuser $handle XTRA lastcmd "${lastbind}$command $text"
		setuser $handle XTRA lastcmdset "[clock seconds]"
	}
	setuser $handle XTRA cmdcount "[expr {[getuser $handle XTRA cmdcount]+1}]"
	set who [lindex [split $text] 0]
	if {$who == ""} {
		putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command nickname|#handle."
		return
	}
	if {[string index $who 0] == "#"} {
		if {![validuser [set hand [string range $who 1 end]]]} {
			putserv "NOTICE $nickname :Handle '#$hand' does not exist in my database."
			return
		} else {
			set nicks [expr {[set x [lsort -unique [service::hand2nicks $hand]]] == "" ? "N/A" : $x}]
		}
	} else {
		set hand [nick2hand $who]
		if {$hand == ""} {
			putserv "NOTICE $nickname :ERROR: '$who' is not on any of my channels."
			return
		} elseif {$hand == "*"} {
			putserv "NOTICE $nickname :ERROR: '$who' is not known to my database."
			return
		} else {
			set nicks [expr {[set x [lsort -unique [service::hand2nicks $hand]]] == "" ? "N/A" : $x}]
		}
	}
	putserv "NOTICE $nickname :Account information for $who (using [expr {[string index $who 0] == "#" ? "nickname(s): [join $nicks ", "]" : "nickname(s): [join $nicks ", "] (under handle: $hand)"}]):"
	set global [matchattr $handle ADnm]
	putserv "NOTICE $nickname :Userid: [getuser $hand XTRA userid][expr {$global ? " - Global userflags: +[chattr $hand]." : "."}]"
	set lvl [list]
	if {[matchattr $hand A]} { lappend lvl "Administrator" }
	if {[matchattr $hand D]} { lappend lvl "Developer" }
	if {[llength $lvl] >= 1} {
		putserv "NOTICE $nickname :$who is a Bot [join $lvl ", "]."
	}
	if {[matchattr $hand S]} { putserv "NOTICE $nickname :$who is a Network Service."; putserv "NOTICE $nickname :End of WHOIS."; return }
	putserv "NOTICE $nickname :Last Login: [expr {[getuser $hand XTRA lastlogin] == "" ? "N/A" : "[clock format [getuser $hand XTRA lastlogin] -format "%D %T"]"}]"
	if {$global} {
		#putserv "NOTICE $nickname :Further information for '$who':"
		putserv "NOTICE $nickname :Last hostname: [getuser $hand XTRA lasthost]"
		putserv "NOTICE $nickname :Email: [getuser $hand XTRA email] - Last set: [expr {[getuser $hand XTRA emailset] == "" ? "N/A" : "[clock format [getuser $hand XTRA emailset] -format "%D %T"]"}]"
		putserv "NOTICE $nickname :Trigger: [getuser $hand XTRA mytrigger] - Last set: [expr {[getuser $hand XTRA mytriggerset] == "" ? "N/A" : "[clock format [getuser $hand XTRA mytriggerset] -format "%D %T"]"}]"
		putserv "NOTICE $nickname :Commands Executed: [expr {[set x [getuser $hand XTRA cmdcount]] == "" ? "0" : $x}] command[expr {$x == "1" ? "" : "s"}] - Last command: [expr {[getuser $hand XTRA lastcmd] == "" ? "N/A" : [getuser $hand XTRA lastcmd]}] - When: [expr {[getuser $hand XTRA lastcmdset] == "" ? "N/A" : "[clock format [getuser $hand XTRA lastcmdset] -format "%D %T"]"}]"
		putserv "NOTICE $nickname :Has '[llength [getuser $hand HOSTS]]' hostmask(s) assigned."
		putserv "NOTICE $nickname :[join [getuser $hand HOSTS] ", "]."
	}
	set list [list]
	foreach chan [channels] {
		if {([matchattr $handle |mnovf $chan] || $global) && [matchattr $hand |mnovf $chan]} {
			lappend list "$chan [lindex [split [chattr $hand $chan] |] 1]"
		}
	}
	if {[llength $list] < 1} {
		putserv "NOTICE $nickname :'$who' is not known on any of my channels."
	} else {
		putserv "NOTICE $nickname :'$who' is known in '[llength $list]' of my channel(s): (#channel +-flags)"
		putserv "NOTICE $nickname :[join $list ", "]."
	}
	putserv "NOTICE $nickname :End of WHOIS."
}
service::register whois service::cmd_whois

# whoami
proc service::cmd_whoami {nickname hostname handle channel text lastbind command} {
	global botnick
	if {[matchattr $handle S]} { return }
	service::track $handle "${lastbind}$command $text"
	set nicks [expr {[set x [lsort -unique [service::hand2nicks $handle]]] == "" ? "N/A" : $x}]
	putserv "NOTICE $nickname :Account information for $nickname (using nickname(s): [join $nicks ", "] (under handle: $handle)):"
	set global [matchattr $handle ADnmovf]
	putserv "NOTICE $nickname :Userid: [getuser $handle XTRA userid][expr {$global ? " - Global userflags: +[chattr $handle]" : "."}]"
	set lvl [list]
	if {[matchattr $handle A]} { lappend lvl "Administrator" }
	if {[matchattr $handle D]} { lappend lvl "Developer" }
	if {[llength $lvl] >= 1} {
		putserv "NOTICE $nickname :You're a Bot [join $lvl ", "]."
	}
	#if {[matchattr $handle S]} { putserv "NOTICE $nickname :You're a Network Service."; putserv "NOTICE $nickname :End of WHOAMI."; return }
	putserv "NOTICE $nickname :Last Login: [expr {[getuser $handle XTRA lastlogin] == "" ? "N/A" : "[clock format [getuser $handle XTRA lastlogin] -format "%D %T"]"}] - Last Hostname: [getuser $handle XTRA lasthost]"
	putserv "NOTICE $nickname :Email: [getuser $handle XTRA email] - Last set: [expr {[getuser $handle XTRA emailset] == "" ? "N/A" : "[clock format [getuser $handle XTRA emailset] -format "%D %T"]"}]"
	putserv "NOTICE $nickname :Trigger: [getuser $handle XTRA mytrigger] - Last set: [expr {[getuser $handle XTRA mytriggerset] == "" ? "N/A" : "[clock format [getuser $handle XTRA mytriggerset] -format "%D %T"]"}]"
	putserv "NOTICE $nickname :Commands Executed: [expr {[set x [getuser $handle XTRA cmdcount]] == "" ? "0" : $x}] command[expr {$x == "1" ? "" : "s"}] - Last command: [expr {[getuser $handle XTRA lastcmd] == "" ? "N/A" : [getuser $handle XTRA lastcmd]}] - When: [expr {[getuser $handle XTRA lastcmdset] == "" ? "N/A" : "[clock format [getuser $handle XTRA lastcmdset] -format "%D %T"]"}]"
	putserv "NOTICE $nickname :You have '[llength [getuser $handle HOSTS]]' hostmask(s) assigned to your account."
	putserv "NOTICE $nickname :[join [getuser $handle HOSTS] ", "]."

	set list [list]
	foreach chan [channels] {
		if {[matchattr $handle |amnovfR $chan]} {
			lappend list "$chan [lindex [split [chattr $handle $chan] |] 1]"
		}
	}
	if {[llength $list] < 1} {
		putserv "NOTICE $nickname :You are not known on any of my channels."
	} else {
		putserv "NOTICE $nickname :You are known in the following [llength $list] channel(s): (#channel +-flags)"
		putserv "NOTICE $nickname :[join $list ", "]."
	}
	putserv "NOTICE $nickname :End of WHOAMI."
}
service::register whoami service::cmd_whoami

# userlist
proc service::cmd_userlist {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm|nmo $channel]} {
		puthelp "NOTICE $nickname :You have no access to this command."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	switch -exact -- [lindex [split $text] 0] {
		"-global" {
			if {![matchattr $handle nm]} { return }
			if {[llength [userlist amnovBS]] == "0"} {
				putserv "NOTICE $nickname :There are no global users."
				return
			}
			set id "0"
			set owner "0"
			set master "0"
			set operator "0"
			set voice "0"
			set ban "0"
			set service "0"
			set status ""
			putserv "NOTICE $nickname :#ID - Handle (Nickname/Offline) - Host(s) - Flags (Global ??):"
			foreach user [userlist amnovBS] {
				if {$user == ""} { return }
				incr id
				if {[matchattr $user A]} {
					set status "Bot Administrator"
				} elseif {[matchattr $user D]} {
					set status "Bot Developer"
				} elseif {[matchattr $user n]} {
					incr owner
					set status "Global Owner"
				} elseif {[matchattr $user m]} {
					incr master
					set status "Global Master"
				} elseif {[matchattr $user o]} {
					incr operator
					set status "Global Operator"
				} elseif {[matchattr $user v]} {
					incr voice
					set status "Global Voice"
				} elseif {[matchattr $user S]} {
					incr service
					set status "Network Service"
				} elseif {[matchattr $user B]} {
					incr ban
					set status "Global Ban"
				}
				if {[set nick [hand2nick $user]] == ""} {
					set nick "Offline"
				}
				putserv "NOTICE $nickname :(#$id) - $user ($nick) - [join [getuser $user HOSTS] ", "] - +[chattr $user] \002($status)\002."
			}
			putserv "NOTICE $nickname :End of global userlist (Total: $id Owner: $owner Master: $master Op: $operator Voice: $voice Service: $service Ban: $ban)."
		}
		"default" {
			if {![matchattr $handle nm|mno $channel]} { return }
			if {[llength [userlist |amnovB $channel]] == "0"} {
				putserv "NOTICE $nickname :There are no $channel users."
				return
			}
			set id "0"
			set owner "0"
			set master "0"
			set operator "0"
			set voice "0"
			set ban "0"
			set status ""
			putserv "NOTICE $nickname :#ID - Handle (Nickname/Offline) - Host(s) - Flags (Channel ??):"
			foreach user [userlist |amnovB $channel] {
				if {$user == ""} { return }
				incr id
				if {[matchattr $user |n $channel]} {
					incr owner
					set status "Channel Owner"
				} elseif {[matchattr $user |m $channel]} {
					incr master
					set status "Channel Master"
				} elseif {[matchattr $user |o $channel]} {
					incr operator
					set status "Channel Operator"
				} elseif {[matchattr $user |v $channel]} {
					incr voice
					set status "Channel Voice"
				} elseif {[matchattr $user |B $channel]} {
					incr ban
					set status "Channel Ban"
				}
				if {[set nick [hand2nick $user]] == ""} {
					set nick "Offline"
				}
				putserv "NOTICE $nickname :(#$id) - $user ($nick) - [join [getuser $user HOSTS] ", "] - +[lindex [split [chattr $user | $channel] |] 1] \002($status)\002."
			}
			putserv "NOTICE $nickname :End of $channel userlist (Total: $id Owner: $owner Master: $master Op: $operator Voice: $voice Ban: $ban)."
		}
	}
}
service::register userlist service::cmd_userlist

# mytrigger, mytrig, trig, trigger
proc service::cmd_mytrigger {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![validuser [nick2hand $nickname]]} {
		puthelp "NOTICE $nickname :You're not known to my userbase, so you can't set a trigger."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	set trigger [join [lindex [split $text] 0]]
	if {$trigger == ""} {
		putserv "NOTICE $nickname :Current mytrigger: [expr {[getuser $handle XTRA mytrigger] == "" ? "not set" : "[getuser $handle XTRA mytrigger]"}] (Triggers: [join "$service::triggers" ", "])."
	} elseif {[lsearch -exact "$service::triggers" $trigger] == "-1"} {
		putserv "NOTICE $nickname :Invalid trigger '$trigger'. Valid triggers are: [join "$service::triggers" ", "]."
	} else {
		setuser $handle XTRA mytrigger "$trigger"
		putserv "NOTICE $nickname :Trigger changed to '$trigger'."
	}
}
service::register {mytrigger mytrig trig trigger} service::cmd_mytrigger
