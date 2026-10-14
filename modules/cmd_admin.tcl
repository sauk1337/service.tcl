#####################################################################
# service.tcl - module: cmd_admin
# Commands: bot administration (addchan, delchan, channels, hop, gban,
# gunban, broadcast, tcl, version, help).
#####################################################################

# addchan, join, +chan
proc service::cmd_addchan {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm]} { return }
	service::track $handle "${lastbind}$command $text"
	if {[set chan [lindex [split $text] 0]] == "" || [string index $chan 0] != "#"} {
		putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command #channel."
	} elseif {[validchan $chan]} {
		putserv "NOTICE $nickname :$chan is already added to my channel list."
	} elseif {[llength [channels]] >= "20"} {
		putserv "NOTICE $nickname :Im full up! I have ([llength [channels]]/20) channels in my list."
	} else {
		channel add $chan
		chattr $handle |+amnov $chan
		putserv "NOTICE $nickname :Channel ($chan) successfully added to my channel list."
	}
}
service::register {addchan join +chan} service::cmd_addchan

# delchan, remchan, part, -chan
proc service::cmd_delchan {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm]} { return }
	service::track $handle "${lastbind}$command $text"
	if {[set chan [lindex [split $text] 0]] == "" || [string index $chan 0] != "#"} {
		putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command #channel."
	} elseif {![validchan $chan]} {
		putserv "NOTICE $nickname :$chan is not added to my channel list."
	} else {
		channel remove $chan
		putserv "NOTICE $nickname :Channel ($chan) successfully removed from my channel list."
	}
}
service::register {delchan remchan part -chan} service::cmd_delchan

# channels
proc service::cmd_channels {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm]} { return }
	service::track $handle "${lastbind}$command"
	set on 0
	set active 0
	set inactive 0
	set users 0
	set op 0
	set voice 0
	set reg 0
	set result ""
	foreach c [channels] {
		set status ""
		set count ""
		set services ""
		if {[botonchan $c]} {
			incr on 1
		}
		if {[channel get $c inactive]} {
			incr inactive 1
		} else {
			incr active 1
		}
		if {[botisop $c]} {
			incr op 1
			set status "@"
		} elseif {[botisvoice $c]} {
			incr voice 1
			set status "+"
		} else {
			incr reg 1
			set status ""
		}
		incr users [set count [llength [chanlist $c]]]
		if {[set services [service::services $c]] == ""} {
			set services "None"
		}
		if {[botonchan $c]} {
			lappend result "${status}${c} \(Channel Count: $count user(s) - Userlist Count: [llength [userlist |almnov $c]] user(s) - Channel Service(s): [join $services ", "]\)"
		} else {
			lappend result "${c} \(currently not on $c\)"
		}
	}
	puthelp "NOTICE $nickname :Channels Count: \([llength [channels]]/20\) channel(s). Im currently on $on of these channels. Statistics (Active on $active - Inactive on $inactive - Operator on $op - Voice on $voice, Regular on $reg - Total user count of all channels: $users user(s))."
	if {[string equal -nocase "-list" [lindex [split $text] 0]]} {
		puthelp "NOTICE $nickname :[join $result " - "]"
	} else {
		foreach line $result {
			if {$line == ""} { return }
			puthelp "NOTICE $nickname :$line"
		}
	}
	puthelp "NOTICE $nickname :Im using [format %.0f [expr (([llength [channels]].0 * 100.0) / 20.0)]]% of my total channel capicity."
}
service::register channels service::cmd_channels

# hop
proc service::cmd_hop {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm]} { return }
	service::track $handle "${lastbind}$command $text"
	set chan [lindex [split $text] 0]
	if {$chan == "" || [string index $chan 0] != "#"} {
		putserv "NOTICE $nickname :Usage: ${lastbind}$command ?#channel?."
	} elseif {![validchan $chan]} {
		putserv "NOTICE $nickname :Channel '$chan' is not a valid channel."
	} else {
		if {[botonchan $chan]} {
			putserv "PART $chan"
		}
		putserv "JOIN $chan"
		putserv "NOTICE $nickname :Successfully hop'd on $chan."
	}
}
service::register hop service::cmd_hop

# tcl
proc service::cmd_tcl {nickname hostname handle channel text lastbind command} {
	global botnick
	if {$service::tcldebug eq "" || ![matchattr $handle [lindex [split $service::tcldebug] 0]]} { return }
	service::track $handle "${lastbind}$command $text"
	catch {[lindex [split $service::tcldebug] 1] $nickname $hostname $handle $channel $text}
}
service::register tcl service::cmd_tcl

# gban, gb
proc service::cmd_gban {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm]} { return }
	service::track $handle "$channel ${lastbind}$command $text"
	set mask [lindex [split $text] 0]
	set time [lindex [split $text] 1]
	set reason [join [lrange [split $text] 2 end]]
	if {$mask == ""} {
		putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command nickname|hostname ?bantime? ?reason?. Bantime format: XmXhXdXwXy (Where 'X' must be a number - For permban specify '0' on its own)."
		return
	}
	if {[regexp {(.+)!(.+)@(.+)} $mask]} {
		if {![regexp {[\d]{1,}(m|h|d|w|y)|^0$} $time]} {
			#putserv "NOTICE $nickname :No bantime specified. Bantime format: XmXhXdXwXy (Where 'X' must be a number - For permban specify '0' on its own)."
			set time "1h"
			set reason [join [lrange [split $text] 1 end]]
		}
		if {$mask == "*!*@*" || $mask == "*!*@" || $mask == "*!**@" || $mask == "*!**@*"} {
			putserv "NOTICE $nickname :Invalid banmask '$mask'."
		} elseif {[matchattr [set hand [service::host2hand $mask]] nm] && ![matchattr $handle n]} {
			putserv "NOTICE $nickname :You are not allowed to ban my bot owner/master."
		} elseif {[matchattr $hand N]} {
			putserv "NOTICE $nickname :You can't global ban a protected nick/user."
		} elseif {[isban $mask]} {
			putserv "NOTICE $nickname :Banmask '$mask' is already global banned."
		} else {
			if {[channel get $service::adminchan service_kickmsg_gban] == ""} {
				channel set $service::adminchan service_kickmsg_gban "$service::kickmsg(gban)"
			}
			channel set $service::adminchan service_gkid "[set id [expr {[channel get $service::adminchan service_gkid] + 1}]]"
			set kickmsg "$service::kickmsg(gban)"
			set kickmsg [string map [list :nickname: $nickname] $kickmsg]
			set kickmsg [string map [list :channel: $channel] $kickmsg]
			set kickmsg [string map [list :homechan: "$service::homechan"] $kickmsg]
			if {$reason == ""} {
				set kickmsg [string map [list :reason: "Violated $service::homechan rules!"] $kickmsg]
			} else {
				set kickmsg [string map [list :reason: "$reason"] $kickmsg]
			}
			set kickmsg [string map [list :bantime: $time] $kickmsg]
			set kickmsg [string map [list :id: $id] $kickmsg]
			newban $mask $handle "$kickmsg" [expr {[set bt [service::tduration $time]]/60}] none
			if {$time == "0"} {
				putserv "NOTICE $nickname :Banmask ($mask) added to my banlist (Expires: Never!)."
			} else {
				putserv "NOTICE $nickname :Banmask ($mask) added to my banlist for $time (Expires: [clock format [expr {[unixtime]+$bt}] -format "%a %d %b %Y at %H:%M:%S %Z"])."
			}
		}
	} elseif {![onchan $mask $channel]} {
		putserv "NOTICE $nickname :$mask isn't on $channel."
	} else {
		if {![regexp {[\d]{1,}(m|h|d|w|y)|^0$} $time]} {
			#putserv "NOTICE $nickname :No bantime specified. Bantime format: XmXhXdXwXy (Where 'X' must be a number - For permban specify '0' on its own)."
			set time "1h"
			set reason [join [lrange [split $text] 1 end]]
		}
		if {[matchattr [set hand [nick2hand $mask]] nm] && ![matchattr $handle n]} {
			putserv "NOTICE $nickname :You are not allowed to ban my bot owner/master."
		} elseif {[matchattr $hand N]} {
			putserv "NOTICE $nickname :You can't global ban a protected nick/user."
		} else {
			if {[string match -nocase *users.quakenet.org [set host *![getchanhost $mask $channel]]]} {
				set host *!*@[lindex [split $host @] 1]
			}
			if {[set kickmsg [channel get $service::adminchan service_kickmsg_gban]] == ""} {
				channel set $service::adminchan service_kickmsg_gban "[set kickmsg $service::kickmsg(gban)]"
			}
			channel set $service::adminchan service_gkid "[set id [expr {[channel get $service::adminchan service_gkid] + 1}]]"
			set kickmsg [string map [list :nickname: $nickname] $kickmsg]
			set kickmsg [string map [list :channel: $channel] $kickmsg]
			if {$reason == ""} {
				set kickmsg [string map [list :reason: "Violated $service::homechan rules!"] $kickmsg]
			} else {
				set kickmsg [string map [list :reason: "$reason"] $kickmsg]
			}
			set kickmsg [string map [list :bantime: $time] $kickmsg]
			set kickmsg [string map [list :id: $id] $kickmsg]
			putquick "MODE $channel +b $host"
			putquick "KICK $channel $mask :$kickmsg"
			newban $host $handle "$kickmsg" [expr {[set bt [service::tduration $time]]/60}] none
			utimer 10 [list pushmode $channel -b $host]
			if {$time == "0"} {
				putserv "NOTICE $nickname :$mask ($host) added to my banlist (Expires: Never!)."
			} else {
				putserv "NOTICE $nickname :$mask ($host) added to my banlist for $time (Expires: [clock format [expr {[unixtime]+$bt}] -format "%a %d %b %Y at %H:%M:%S %Z"])."
			}
		}
	}
}
service::register {gban gb} service::cmd_gban

# gunban, gub
proc service::cmd_gunban {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm]} { return }
	service::track $handle "$channel ${lastbind}$command $text"
	set mask [lindex [split $text] 0]
	if {$mask == ""} {
		putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command #id|hostname."
	} elseif {[regexp {^#[0-9]{1,}$} $mask]} {
		set mask [string trimleft $mask #]
		if {[llength [banlist]] == "0"} {
			putserv "NOTICE $nickname :No registered global bans."
		} elseif {$mask == "0" || $mask > [llength [banlist]]} {
			putserv "NOTICE $nickname :Invalid ban id #$mask."
		} else {
			set id "0"
			set ban "0"
			foreach bann [banlist] {
				if {$bann == ""} { return }
				incr id
				if {$id == $mask} {
					set ban [lindex $bann 0]
				}
			}
			if {$ban == "0"} {
				putserv "NOTICE $nickname :Ban ID #$mask does not exist."
			} elseif {[killban $ban]} {
				putserv "NOTICE $nickname :Ban ID #$mask ($ban) successfully removed from global banlist."
				if {[ischanban $ban $channel] && [botisop $channel]} {
					pushmode $channel -b $ban
				}
			} else {
				putserv "NOTICE $nickname :Error removing ban id #$mask ($ban) from global banlist."
			}
		}
	} elseif {[regexp {(.+)!(.+)@(.+)} $mask]} {
		set found "0"
		foreach ban [banlist] {
			if {[string match -nocase $mask [lindex $ban 0]]} {
				set found 1
				break
			}
		}
		if {$found} {
			if {[killban $mask]} {
				putserv "NOTICE $nickname :Banmask $mask successfully removed from global banlist."
				if {[ischanban $mask $channel] && [botisop $channel]} {
					pushmode $channel -b $mask
				}
			}
		} else {
			putserv "NOTICE $nickname :Banmask '$mask' does not exist."
		}
	}
}
service::register {gunban gub} service::cmd_gunban

# spam, broadcast
proc service::cmd_spam {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm]} { return }
	service::track $handle "$channel ${lastbind}$command $text"
	if {$text == ""} {
		putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command <message>."
	} else {
		set list ""
		set id "0"
		foreach chan [channels] {
			if {$chan == ""} { return }
			if {![string equal -nocase $service::homechan $chan] && ![string equal -nocase $service::adminchan $chan] && ![string equal -nocase $service::helpchan $chan]} {
				puthelp "PRIVMSG $chan :\(broadcast\) $text"
				incr id 1
			}
		}
		putserv "NOTICE $nickname :Done. Broadcasted to ($id/[llength [channels]]) Successfully."
	}
}
service::register {spam broadcast} service::cmd_spam

# version
proc service::cmd_version {nickname hostname handle channel text lastbind command} {
	global botnick
	service::track $handle "${lastbind}$command"
	puthelp "NOTICE $nickname :$service::script v${service::version} by $service::author loaded! (Line Count: $service::linecount)."
}
service::register version service::cmd_version

# commands, help
proc service::cmd_commands {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![validuser [nick2hand $nickname]]} { return }
	service::track $handle "${lastbind}$command"
	set trig [getuser $handle XTRA mytrigger]
	if {$trig == ""} {
		setuser $handle XTRA mytrigger $service::trigger
		set trig "$service::trigger"
	}
	putserv "NOTICE $nickname :${trig}adduser, ${trig}deluser, ${trig}access, ${trig}whois, ${trig}whoami,${trig}auth, ${trig}protect, ${trig}spamscan, ${trig}flood, ${trig}topic, ${trig}clonescan, ${trig}flyby, ${trig}ao, ${trig}av, ${trig}known, ${trig}autolimit, ${trig}vip, ${trig}badword, ${trig}welcome, ${trig}bitchmode, ${trig}chanflags, ${trig}status, ${trig}mytrigger, ${trig}version, ${trig}invite, ${trig}op, ${trig}deop, ${trig}voice, ${trig}saveop, ${trig}reop, ${trig}devoice, ${trig}kick, ${trig}ban, ${trig}unban, ${trig}banlist, ${trig}baninfo, ${trig}banclear, ${trig}userlist, ${trig}say, ${trig}commands."
	if {[matchattr $handle n]} {
		putserv "NOTICE $nickname :The following global commands are available to you: ${trig}auth, ${trig}tcl, ${trig}addchan, ${trig}delchan, ${trig}channels, ${trig}gban, ${trig}gunban, ${trig}banlist -global, ${trig}banclear -global, ${trig}userlist -global."
	} elseif {[matchattr $handle m]} {
		putserv "NOTICE $nickname :The following global commands are available to you: ${trig} auth, ${trig}addchan, ${trig}delchan, ${trig}channels, ${trig}gban, ${trig}gunban, ${trig}banlist -global, ${trig}banclear -global, ${trig}userlist -global."
	}
}
service::register {commands help} service::cmd_commands
