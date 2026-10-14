#####################################################################
# service.tcl - module: cmd_channel
# Commands: channel operation (op/voice, kick, ban/unban, banlist,
# banclear, invite, mode, say, saveop/reop).
#####################################################################

# invite
proc service::cmd_invite {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm|nmo $channel]} {
		puthelp "NOTICE $nickname :You have no access to this command."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	set invite [lindex [split $text] 0]
	if {$invite == ""} {
		putserv "NOTICE $nickname :Syntax: ${lastbind}$command <nickname>."
	} elseif {[onchan $invite $channel]} {
		putserv "NOTICE $nickname :ERROR: $invite is already on $channel."
	} elseif {![botisop $channel]} {
		putserv "NOTICE $nickname :I need op to do that!"
	} else {
		puthelp "INVITE $invite $channel"
		putserv "NOTICE $nickname :Invited $invite to $channel."
	}
}
service::register invite service::cmd_invite

# op, voice, deop, devoice
proc service::cmd_op {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm|nmov $channel]} {
		puthelp "NOTICE $nickname :You have no access to this command."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	if {![botisop $channel]} {
		putserv "NOTICE $nickname :I need op to do that!"
		return
	}
	if {$text == ""} {
		switch -exact -- $command {
			"op" {
				if {![isop $nickname $channel] && [matchattr $handle nm|nmo $channel]} {
					putquick "MODE $channel +o $nickname"
				}
			}
			"deop" {
				if {[isop $nickname $channel] && [matchattr $handle nm|nmo $channel]} {
					putquick "MODE $channel -o $nickname"
				}
			}
			"voice" {
				if {![isvoice $nickname $channel] && [matchattr $handle nm|nmovf $channel]} {
					putquick "MODE $channel +v $nickname"
				}
			}
			"devoice" {
				if {[isvoice $nickname $channel] && [matchattr $handle nm|nmovf $channel]} {
					putquick "MODE $channel -v $nickname"
				}
			}
		}
	} elseif {[regexp {(.+)\*} $text] || [regexp {\*(.+)} $text]} {
		if {![matchattr $handle nm|nm $channel]} {
			putserv "NOTICE $nickname :ERROR: Only $channel owners/masters can mass$command."
			return
		}
		if {[channel get $channel service_bitchmode]} {
			putserv "NOTICE $nickname :ERROR: Massmodes disabled due to bitchmode being activated."
			return
		}
		set list ""
		set text [join [split $text]]
		switch -exact -- $command {
			"op" {
				foreach user [chanlist $channel] {
					if {[string match -nocase "$text" "$user"] && ![isop $user $channel] && ![matchattr [nick2hand $user] Bd|Bd $channel]} {
						lappend list $user
					}
					if {[llength $list] == "6"} {
						putquick "MODE $channel +oooooo [join $list " "]"
						set list ""
					}
				}
				if {[llength $list] > 0} {
					putquick "MODE $channel +[string repeat "o" [llength $list]] [join $list " "]"
					set list ""
				}
			}
			"deop" {
				foreach user [chanlist $channel] {
					if {[string match -nocase "$text" "$user"] && [isop $user $channel] && ![string equal -nocase $botnick $user]} {
						lappend list $user
					}
					if {[llength $list] == "6"} {
						putquick "MODE $channel -oooooo [join $list " "]"
						set list ""
					}
				}
				if {[llength $list] > 0} {
					putquick "MODE $channel -[string repeat "o" [llength $list]] [join $list " "]"
					set list ""
				}
			}
			"voice" {
				foreach user [chanlist $channel] {
					if {[string match -nocase "$text" "$user"] && ![isvoice $user $channel]} {
						lappend list $user
					}
					if {[llength $list] == "6"} {
						putquick "MODE $channel +vvvvvv [join $list " "]"
						set list ""
					}
				}
				if {[llength $list] > 0} {
					putquick "MODE $channel +[string repeat "v" [llength $list]] [join $list " "]"
					set list ""
				}
			}
			"devoice" {
				foreach user [chanlist $channel] {
					if {[string match -nocase "$text" "$user"] && [isvoice $user $channel]} {
						lappend list $user
					}
					if {[llength $list] == "6"} {
						putquick "MODE $channel -vvvvvv [join $list " "]"
						set list ""
					}
				}
				if {[llength $list] > 0} {
					putquick "MODE $channel -[string repeat "v" [llength $list]] [join $list " "]"
					set list ""
				}
			}
		}
	} elseif {[lindex [split $text] 0] == "\*"} {
		if {![matchattr $handle nm|nm $channel]} {
			putserv "NOTICE $nickname :Error: Only $channel owners/masters can mass$command."
		} elseif {[channel get $channel service_bitchmode]} {
			putserv "NOTICE $nickname :ERROR: Massmodes disabled due to bitchmode being activated."
		} else {
			set list ""
			switch -exact -- $command {
				"op" {
					foreach user [chanlist $channel] {
						if {$user != "" && ![string  equal -nocase $botnick $user] && ![isop $user $channel]} {
							lappend list $user
						}
						if {[llength $list] == "6"} {
							putquick "MODE $channel +oooooo [join $list " "]"
							set list ""
						}
					}
					if {[llength $list] > 0} {
						putquick "MODE $channel +[string repeat "o" [llength $list]] [join $list " "]"
						set list ""
					}
				}
				"deop" {
					foreach user [chanlist $channel] {
						if {$user != "" && ![string equal -nocase $botnick $user] && [isop $user $channel] && ![isbotnick $user]} {
							lappend list $user
						}
						if {[llength $list] == "6"} {
							putquick "MODE $channel -oooooo [join $list " "]"
							set list ""
						}
					}
					if {[llength $list] > 0} {
						putquick "MODE $channel -[string repeat "o" [llength $list]] [join $list " "]"
						set list ""
					}
				}
				"voice" {
					foreach user [chanlist $channel] {
						if {$user != "" && ![string equal -nocase $botnick $user] && ![isvoice $user $channel]} {
							lappend list $user
						}
						if {[llength $list] == "6"} {
							putquick "MODE $channel +vvvvvv [join $list " "]"
							set list ""
						}
					}
					if {[llength $list] > 0} {
						putquick "MODE $channel +[string repeat "v" [llength $list]] [join $list " "]"
						set list ""
					}
				}
				"devoice" {
					foreach user [chanlist $channel] {
						if {$user != "" && ![string equal -nocase $botnick $user] && [isvoice $user $channel]} {
							lappend list $user
						}
						if {[llength $list] == "6"} {
							putquick "MODE $channel -vvvvvv [join $list " "]"
							set list ""
						}
					}
					if {[llength $list] > 0} {
						putquick "MODE $channel -[string repeat "v" [llength $list]] [join $list " "]"
						set list ""
					}
				}
			}
		}
	} else {
		if {[llength [split $text]] > 6} {
			putserv "NOTICE $nickname :Error: I can only $command 6 user(s) at a time."
		} else {
			if {[llength [split $text]] == "1"} {
				if {[string equal -nocase $botnick $text] && ($command == "op" || $command == "deop")} {
					putserv "NOTICE $nickname :I can't $command myself!"
				} elseif {![onchan $text $channel]} {
					putserv "NOTICE $nickname :$text isn't on $channel."
				} else {
					switch -exact -- $command {
						"op" {
							if {![matchattr $handle nm|nmo $channel]} { return }
							if {[isop $text $channel]} {
								putserv "NOTICE $nickname :Error: $text is already op'd."
							} elseif {[channel get $channel service_bitchmode] && ![matchattr [nick2hand $text] bnmoS|nmo $channel]} {
								putserv "NOTICE $nickname :Error: Could not op '$text' due to channel setting 'bitchmode'."
							} else {
								putquick "MODE $channel +o $text"
							}
						}
						"deop" {
							if {![matchattr $handle nm|nmo $channel]} { return }
							if {![isop $text $channel]} {
								putserv "NOTICE $nickname :Error: $text is not op'd."
							} else {
								putquick "MODE $channel -o $text"
							}
						}
						"voice" {
							if {![matchattr $handle nm|nmo $channel]} { return }
							if {[isvoice $text $channel]} {
								putserv "NOTICE $nickname :Error: $text is already voice'd."
							} elseif {[channel get $channel service_bitchmode] && ![matchattr [nick2hand $text] bnmovfS|nmovfS $channel]} {
								putserv "NOTICE $nickname :Error: Could not voice '$text' due to channel setting 'bitchmode'."
							} else {
								putquick "MODE $channel +v $text"
							}
						}
						"devoice" {
							if {![matchattr $handle nm|nmo $channel]} { return }
							if {![isvoice $text $channel]} {
								putserv "NOTICE $nickname :Error: $text is not voice'd."
							} else {
								putquick "MODE $channel -v $text"
							}
						}
					}
				}
			} elseif {[llength [split $text]] > 1} {
				if {[lsearch -exact -nocase [split $text] $botnick] != -1 && ($command == "op" || $command == "deop")} {
					putserv "NOTICE $nickname :Error: I can't $command myself!"
				} else {
					set ylist ""
					set nlist ""
					switch -exact -- $command {
						"op" {
							if {![matchattr $handle nm|nmo $channel]} { return }
							foreach user [split $text] {
								if {$user == ""} { return }
								if {[isop $user $channel] || ([channel get $channel service_bitchmode] && ![matchattr [nick2hand $user] bnmoS|nmoS $channel])} {
									lappend nlist $user
								} else {
									lappend ylist $user
								}
							}
							if {$ylist != ""} {
								putquick "MODE $channel +[string repeat "o" [llength $ylist]] [join $ylist " "]"
								return
							}
							if {$nlist != ""} {
								putserv "NOTICE $nickname :Could not op user(s) '[join $nlist ", "]' because they are either already op'd or there are conflicting channel settings."
								return
							}
						}
						"deop" {
							if {![matchattr $handle nm|nmo $channel]} { return }
							foreach user [split $text] {
								if {$user == ""} { return }
								if {![isop $user $channel] || [string equal -nocase $botnick $user]} {
									lappend nlist $user
								} else {
									lappend ylist $user
								}
							}
							if {$ylist != ""} {
								putquick "MODE $channel -[string repeat "o" [llength $ylist]] [join $ylist " "]"
								return
							}
							if {$nlist != ""} {
								putserv "NOTICE $nickname :Could not deop user(s) '[join $nlist ", "]' because they are not op'd."
								return
							}
						}
						"voice" {
							if {![matchattr $handle nm|nmo $channel]} { return }
							foreach user [split $text] {
								if {$user == ""} { return }
								if {[isvoice $user $channel] || ([channel get $channel service_bitchmode] && ![matchattr [nick2hand $user] bnmovfS|nmovfS $channel])} {
									lappend nlist $user
								} else {
									lappend ylist $user
								}
							}
							if {$ylist != ""} {
								putquick "MODE $channel +[string repeat "v" [llength $ylist]] [join $ylist " "]"
								return
							}
							if {$nlist != ""} {
								putserv "NOTICE $nickname :Could not voice user(s) '[join $nlist ", "]' because they are either already voice'd or there are conflicting channel settings."
								return
							}
						}
						"devoice" {
							if {![matchattr $handle nm|nmo $channel]} { return }
							foreach user [split $text] {
								if {$user == ""} { return }
								if {![isvoice $user $channel]} {
									lappend nlist $user
								} else {
									lappend ylist $user
								}
							}
							if {$ylist != ""} {
								putquick "MODE $channel -[string repeat "v" [llength $ylist]] [join $ylist " "]"
								return
							}
							if {$nlist != ""} {
								putserv "NOTICE $nickname :Could not devoice user(s) '[join $nlist ", "]' because they are not voice'd."
								return
							}
						}
					}
				}
			}
		}
	}
}
service::register {op voice deop devoice} service::cmd_op

# mode
proc service::cmd_mode {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm|nmo $channel]} {
		puthelp "NOTICE $nickname :You have no access to this command."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	#modes = bCcdDiklmnNoprstuv
	if {$text == ""} {
		putserv "NOTICE $nickname :${lastbind}$command +-modes."
	} elseif {![regexp {\+|\-} [string index $text 0]]} {
		putserv "NOTICE $nickname :Mode(s) must start with a '+' or '-'."
	} else {
		putserv "MODE $channel $text"
	}
}
service::register mode service::cmd_mode

# kick
proc service::cmd_kick {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm|nmo $channel]} {
		puthelp "NOTICE $nickname :You have no access to this command."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	set who [lindex [split $text] 0]
	set reason [join [lrange [split $text] 1 end]]
	if {$who == ""} {
		putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command nickname \?reason\?."
	} elseif {![onchan $who $channel]} {
		putserv "NOTICE $nickname :$who isn't on $channel."
	} elseif {![botisop $channel]} {
		putserv "NOTICE $nickname :I need op to do that!"
	} elseif {[string equal -nocase $botnick $who]} {
		putserv "NOTICE $nickname :You can't kick me!"
	} else {
		if {[channel get $channel service_kickmsg_kick] == ""} {
			channel set $channel service_kickmsg_kick "$service::kickmsg(userkick)"
		}
		channel set $channel service_kid "[expr {[channel get $channel service_kid] + 1}]"
		set kickmsg [channel get $channel service_kickmsg_kick]
		set id [channel get $channel service_kid]
		set kickmsg [string map [list :nickname: $nickname] $kickmsg]
		set kickmsg [string map [list :channel: $channel] $kickmsg]
		if {$reason == ""} {
			set kickmsg [string map [list :reason: "$service::defaultreason"] $kickmsg]
		} else {
			set kickmsg [string map [list :reason: "$reason"] $kickmsg]
		}
		set kickmsg [string map [list :id: $id] $kickmsg]
		putquick "KICK $channel $who :$kickmsg"
	}
}
service::register kick service::cmd_kick

# ban, kb
proc service::cmd_ban {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm|nmo $channel]} {
		puthelp "NOTICE $nickname :You have no access to this command."
		return
	}
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
		} elseif {[matchattr $hand |n $channel] && ![matchattr $handle |n $channel]} {
			putserv "NOTICE $nickname :You don't have enough access to ban a channel owner."
		} elseif {[matchattr $hand |m $channel] && ![matchattr $handle |n $channel]} {
			putserv "NOTICE $nickname :You don't have enough access to ban a channel master."
		} elseif {[matchattr $hand |o $channel] && ![matchattr $handle |nm $channel]} {
			putserv "NOTICE $nickname :You don't have enough access to ban a channel operator."
		} elseif {[matchattr $hand |v $channel] && ![matchattr $handle |nmo $channel]} {
			putserv "NOTICE $nickname :You don't have enough access to ban a channel voice."
		} elseif {[matchattr $hand N]} {
			putserv "NOTICE $nickname :You can't ban a protected nick/user."
		} elseif {[isban $mask $channel]} {
			putserv "NOTICE $nickname :Banmask '$mask' is already banned on $channel."
		} else {
			if {[channel get $channel service_kickmsg_ban] == ""} {
				channel set $channel service_kickmsg_ban "$service::kickmsg(userban)"
			}
			channel set $channel service_kid "[set id [expr {[channel get $channel service_kid] + 1}]]"
			set kickmsg [channel get $channel service_kickmsg_ban]
			set kickmsg [string map [list :nickname: $nickname] $kickmsg]
			set kickmsg [string map [list :channel: $channel] $kickmsg]
			if {$reason == ""} {
				set kickmsg [string map [list :reason: "$service::defaultreason"] $kickmsg]
			} else {
				set kickmsg [string map [list :reason: "$reason"] $kickmsg]
			}
			set kickmsg [string map [list :bantime: $time] $kickmsg]
			set kickmsg [string map [list :id: $id] $kickmsg]
			putquick "MODE $channel +b $mask"
			newchanban $channel $mask $handle "$kickmsg" [expr {[set bt [service::tduration $time]]/60}]
			if {$time == "0"} {
				putserv "NOTICE $nickname :Banmask ($mask) added to my banlist (Expires: Never!)."
			} else {
				putserv "NOTICE $nickname :Banmask ($mask) added to my banlist for $time (Expires: [clock format [expr {[unixtime]+$bt}] -format "%a %d %b %Y at %H:%M:%S %Z"])."
			}
		}
	} elseif {![onchan $mask $channel]} {
		putserv "NOTICE $nickname :$mask isn't on $channel."
	} elseif {[string equal -nocase $botnick $mask]} {
		putserv "NOTICE $nickname :You can't ban me!"
	} else {
		if {![regexp {[\d]{1,}(m|h|d|w|y)|^0$} $time]} {
			#putserv "NOTICE $nickname :No bantime specified. Bantime format: XmXhXdXwXy (Where 'X' must be a number - For permban specify '0' on its own)."
			set time "1h"
			set reason [join [lrange [split $text] 1 end]]
		}
		if {[matchattr [set hand [service::resolve $mask [nick2hand $mask $channel]]] nm] && ![matchattr $handle n]} {
			putserv "NOTICE $nickname :You are not allowed to ban my bot owner/master."
		} elseif {[matchattr $hand |n $channel] && ![matchattr $handle |n $channel]} {
			putserv "NOTICE $nickname :You don't have enough access to ban a channel owner."
		} elseif {[matchattr $hand |m $channel] && ![matchattr $handle |n $channel]} {
			putserv "NOTICE $nickname :You don't have enough access to ban a channel master."
		} elseif {[matchattr $hand |o $channel] && ![matchattr $handle |nm $channel]} {
			putserv "NOTICE $nickname :You don't have enough access to ban a channel operator."
		} elseif {[matchattr $hand |v $channel] && ![matchattr $handle |nmo $channel]} {
			putserv "NOTICE $nickname :You don't have enough access to ban a channel voice."
		} elseif {[matchattr $hand N]} {
			putserv "NOTICE $nickname :You can't ban a protected nick/user."
		} else {
			set host [service::banmask [getchanhost $mask $channel]]
			if {[channel get $channel service_kickmsg_ban] == ""} {
				channel set $channel service_kickmsg_ban "$service::kickmsg(userban)"
			}
			channel set $channel service_kid "[set id [expr {[channel get $channel service_kid] + 1}]]"
			set kickmsg [channel get $channel service_kickmsg_ban]
			set kickmsg [string map [list :nickname: $nickname] $kickmsg]
			set kickmsg [string map [list :channel: $channel] $kickmsg]
			if {$reason == ""} {
				set kickmsg [string map [list :reason: "-"] $kickmsg]
			} else {
				set kickmsg [string map [list :reason: "$reason"] $kickmsg]
			}
			set kickmsg [string map [list :bantime: $time] $kickmsg]
			set kickmsg [string map [list :id: $id] $kickmsg]
			putquick "MODE $channel +b $host"
			putquick "KICK $channel $mask :$kickmsg"
			newchanban $channel $host $handle "$kickmsg" [expr {[set bt [service::tduration $time]]/60}]
			if {$time == "0"} {
				putserv "NOTICE $nickname :$mask ($host) added to my banlist (Expires: Never!)."
			} else {
				putserv "NOTICE $nickname :$mask ($host) added to my banlist for $time (Expires: [clock format [expr {[unixtime]+$bt}] -format "%a %d %b %Y at %H:%M:%S %Z"])."
			}
		}
	}
}
service::register {ban kb} service::cmd_ban

# unban, ub
proc service::cmd_unban {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm|nmo $channel]} {
		puthelp "NOTICE $nickname :You have no access to this command."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	set mask [lindex [split $text] 0]
	if {$mask == ""} {
		putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command #id|hostname."
	} elseif {$mask == "\*" || [string equal -nocase all $mask]} {
		putserv "NOTICE $nickname :To unbanall, please use the '${lastbind}banclear' command (To unban all permbans too, please use '${lastbind}banclear all')."
	} elseif {[regexp {^#[0-9]{1,}$} $mask]} {
		set mask [string trimleft $mask #]
		if {[llength [banlist $channel]] == "0"} {
			putserv "NOTICE $nickname :No registered bans for $channel."
		} elseif {$mask == "0" || $mask > [llength [banlist $channel]]} {
			putserv "NOTICE $nickname :Invalid ban id #$mask."
		} else {
			set id "0"
			set ban "0"
			foreach bann [banlist $channel] {
				if {$bann == ""} { return }
				incr id
				if {$id == $mask} {
					set ban [lindex $bann 0]
				}
			}
			if {$ban == "0"} {
				putserv "NOTICE $nickname :Ban ID #$mask does not exist."
			} elseif {[killchanban $channel $ban]} {
				putserv "NOTICE $nickname :Ban ID #$mask ($ban) successfully removed from $channel banlist."
				if {[ischanban $ban $channel] && [botisop $channel]} {
					pushmode $channel -b $ban
					flushmode $channel
				}
			} else {
				putserv "NOTICE $nickname :Error removing ban id #$mask ($ban) from $channel banlist."
			}
		}
	} elseif {[regexp {(.+)!(.+)@(.+)} $mask]} {
		set found "0"
		foreach ban [banlist $channel] {
			if {[string match -nocase $mask [lindex $ban 0]]} {
				set found 1
				break
			}
		}
		if {$found} {
			if {[killchanban $channel $mask]} {
				putserv "NOTICE $nickname :Banmask $mask successfully removed from $channel banlist."
				if {[ischanban $mask $channel] && [botisop $channel]} {
					pushmode $channel -b $mask
					flushmode $channel
				}
			}
		} else {
			set found "0"
			foreach chanban [chanbans $channel] {
				if {[string match -nocase $mask [lindex $chanban 0]]} {
					set found 1
					break
				}
			}
			if {$found} {
				if {![botisop $channel]} {
					putserv "NOTICE $nickname :I need op to unban $mask."
				} else {
					pushmode $channel -b $mask
					flushmode $channel
					putserv "NOTICE $nickname :Channel ban $mask removed."
				}
			} else {
				putserv "NOTICE $nickname :Banmask $mask does not exist."
			}
		}
	}
}
service::register {unban ub} service::cmd_unban

# banlist, bl
proc service::cmd_banlist {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm|nmo $channel]} {
		puthelp "NOTICE $nickname :You have no access to this command."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	switch -exact -- [lindex [split $text] 0] {
		"-global" {
			if {![matchattr $handle nm]} { return }
			if {[llength [banlist]] == "0"} {
				putserv "NOTICE $nickname :There are no global bans."
				return
			}
			set id "0"
			set perm "0"
			set nonperm "0"
			putserv "NOTICE $nickname :#ID - Banmask - Creator - Expire Time:"
			foreach ban [banlist] {
				if {$ban == ""} { return }
				incr id
				putserv "NOTICE $nickname :(#$id) - [lindex $ban 0] - [lindex $ban 5] - [expr {([expr [lindex $ban 2] - [unixtime]] > 0) ? "[clock format [lindex $ban 2] -format "%a %d %b %Y at %H:%M:%S %Z"] (in [duration [expr [lindex $ban 2] - [unixtime]]])" : "Never! (Perm ban)" }]"
				if {[ispermban [lindex $ban 0]]} {
					incr perm
				} else {
					incr nonperm
				}
			}
			putserv "NOTICE $nickname :End of global banlist (Total: $id Permanent: $perm Non-permanent: $nonperm)."
		}
		"default" {
			if {![matchattr $handle nm|nmo $channel]} { return }
			if {[llength [banlist $channel]] == "0"} {
				putserv "NOTICE $nickname :There are no $channel bans."
				return
			}
			set id "0"
			set perm "0"
			set nonperm "0"
			putserv "NOTICE $nickname :#ID - Banmask - Creator - Expire Time:"
			foreach ban [banlist $channel] {
				if {$ban == ""} { return }
				incr id
				putserv "NOTICE $nickname :(#$id) - [lindex $ban 0] - [lindex $ban 5] - [expr {([expr [lindex $ban 2] - [unixtime]] > 0) ? "[clock format [lindex $ban 2] -format "%a %d %b %Y at %H:%M:%S %Z"] (in [duration [expr [lindex $ban 2] - [unixtime]]])" : "Never! (Perm ban)" }]"
				if {[ispermban [lindex $ban 0] $channel]} {
					incr perm
				} else {
					incr nonperm
				}
			}
			putserv "NOTICE $nickname :End of $channel banlist (Total: $id Permanent: $perm Non-permanent: $nonperm)."
		}
	}
}
service::register {banlist bl} service::cmd_banlist

# baninfo
proc service::cmd_baninfo {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm|nmo $channel]} {
		puthelp "NOTICE $nickname :You have no access to this command."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	switch -exact -- [lindex [split $text] 0] {
		"-global" {
			if {![matchattr $handle nm]} { return }
			if {[llength [banlist]] == "0"} {
				putserv "NOTICE $nickname :There are no global bans."
				return
			}
			if {[set mask [lindex [split $text] 1]] == ""} {
				putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command #id|hostname."
			} elseif {[regexp -nocase -- {^#[0-9]{1,}$} $mask]} {
				set mask [string trimleft $mask #]
				set id 0
				set found 0
				foreach ban [banlist] {
					if {$ban == ""} { continue }
					incr id 1
					if {$id == $mask} {
						set found 1
						putserv "NOTICE $nickname :(#$id) - Banmask: [lindex $ban 0] - Created by: [lindex $ban 5] on [clock format [lindex $ban 3] -format "%a %d %b %Y at %H:%M:%S %Z"] - Expires: [expr {([expr [lindex $ban 2] - [unixtime]] > 0) ? "[clock format [lindex $ban 2] -format "%a %d %b %Y at %H:%M:%S %Z"] (in [duration [expr [lindex $ban 2] - [unixtime]]])" : "Never! (Perm ban)" }] - Reason: [set reason [lindex $ban 1]][expr {[string range $reason end end] != "." ? "." : ""}]"
						break
					}
				}
				if {!$found} {
					putserv "NOTICE $nickname :Banmask ID #$mask does not exists."
				}
			} elseif {[regexp {(.+)!(.+)@(.+)} $mask]} {
				set found 0; set id 0
				foreach ban [banlist] {
					if {$ban == ""} { continue }
					incr id 1
					if {[string equal -nocase [lindex [split $ban] 0] $mask]} {
						set found 1
						putserv "NOTICE $nickname :(#$id) - Banmask: [lindex $ban 0] - Created by: [lindex $ban 5] on [clock format [lindex $ban 3] -format "%a %d %b %Y at %H:%M:%S %Z"] - Expires: [expr {([expr [lindex $ban 2] - [unixtime]] > 0) ? "[clock format [lindex $ban 2] -format "%a %d %b %Y at %H:%M:%S %Z"] (in [duration [expr [lindex $ban 2] - [unixtime]]])" : "Never! (Perm ban)" }] - Reason: [set reason [lindex $ban 1]][expr {[string range $reason end end] != "." ? "." : ""}]"
						break
					}
				}
				if {!$found} {
					putserv "NOTICE $nickname :Banmask $mask does not exists."
				}
			} else {
				putserv "NOTICE $nickname :Invalid #id/hostname supplied. Please supply a ban #id or a hostname in the format nick!user@somehost.tld (wildcards allowed)."
			}
		}
		"default" {
			if {![matchattr $handle nm|nmo $channel]} { return }
			if {[llength [banlist $channel]] == "0"} {
				putserv "NOTICE $nickname :There are no $channel bans."
				return
			}
			if {[set mask [lindex [split $text] 0]] == ""} {
				putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command #id|hostname."
			} elseif {[regexp -nocase -- {^#[0-9]{1,}$} $mask]} {
				set mask [string trimleft $mask #]
				set id 0
				set found 0
				foreach ban [banlist $channel] {
					if {$ban == ""} { continue }
					incr id 1
					if {$id == $mask} {
						set found 1
						putserv "NOTICE $nickname :(#$id) - Banmask: [lindex $ban 0] - Created by: [lindex $ban 5] on [clock format [lindex $ban 3] -format "%a %d %b %Y at %H:%M:%S %Z"] - Expires: [expr {([expr [lindex $ban 2] - [unixtime]] > 0) ? "[clock format [lindex $ban 2] -format "%a %d %b %Y at %H:%M:%S %Z"] (in [duration [expr [lindex $ban 2] - [unixtime]]])" : "Never! (Perm ban)" }] - Reason: [set reason [lindex $ban 1]][expr {[string range $reason end end] != "." ? "." : ""}]"
						break
					}
				}
				if {!$found} {
					putserv "NOTICE $nickname :Banmask ID #$mask does not exists."
				}
			} elseif {[regexp {(.+)!(.+)@(.+)} $mask]} {
				set found 0; set id 0
				foreach ban [banlist $channel] {
					if {$ban == ""} { continue }
					incr id 1
					if {[string equal -nocase [lindex [split $ban] 0] $mask]} {
						set found 1
						putserv "NOTICE $nickname :(#$id) - Banmask: [lindex $ban 0] - Created by: [lindex $ban 5] on [clock format [lindex $ban 3] -format "%a %d %b %Y at %H:%M:%S %Z"] - Expires: [expr {([expr [lindex $ban 2] - [unixtime]] > 0) ? "[clock format [lindex $ban 2] -format "%a %d %b %Y at %H:%M:%S %Z"] (in [duration [expr [lindex $ban 2] - [unixtime]]])" : "Never! (Perm ban)" }] - Reason: [set reason [lindex $ban 1]][expr {[string range $reason end end] != "." ? "." : ""}]"
						break
					}
				}
				if {!$found} {
					putserv "NOTICE $nickname :Banmask $mask does not exists."
				}
			} else {
				putserv "NOTICE $nickname :Invalid #id/hostname supplied. Please supply a ban #id or a hostname in the format nick!user@somehost.tld (wildcards allowed)."
			}
		}
	}
}
service::register baninfo service::cmd_baninfo

# banclear, bc
proc service::cmd_banclear {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm|nmo $channel]} {
		puthelp "NOTICE $nickname :You have no access to this command."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	set option [lindex [split $text] 0]
	if {[string equal -nocase -global $option]} {
		if {![matchattr $handle nm]} { return }
		if {[string equal -nocase all [lindex [split $text] 1]]} {
			set id "0"
			set perm "0"
			set nonperm "0"
			set killed "0"
			set perml [list]
			set nonperml [list]
			foreach ban [banlist] {
				if {$ban == ""} { return }
				set ban [lindex $ban 0]
				incr id
				if {[ispermban $ban]} {
					incr perm
					if {[killban $ban]} {
						incr killed
						lappend perml $ban
					}
				} else {
					incr nonperm
					if {[killban $ban]} {
						incr killed
						lappend nonperml $ban
					}
				}

			}
			if {$killed == "1"} {
				set x ban
			} else {
				set x bans
			}
			if {[llength $perml] > 0 || [llength $nonperml] > 0} {
				foreach c [channels] {
					foreach b "$perml $nonperml" {
						if {$b == ""} { continue }
						pushmode $c -b $b
					}
					flushmode $c
				}
			}
			if {[llength $perml] > 0} {
			putserv "NOTICE $nickname :Removed registered global permban[expr {[llength $perml] > 1 ? "s" : ""}] \( [join $perml " "] \)."
			}
			if {[llength $nonperml] > 0} {
				putserv "NOTICE $nickname :Removed registered global tempban[expr {[llength $nonperml] > 1 ? "s" : ""}] \( [join $nonperml " "] \)."
			}
			putserv "NOTICE $nickname :I removed a total of $killed $x (Total: $id Permanent: $perm Non-permanent: $nonperm)."
		} else {
			set id "0"
			set perm "0"
			set nonperm "0"
			set killed "0"
			set unban [list]
			foreach ban [banlist] {
				if {$ban == ""} { return }
				set ban [lindex $ban 0]
				incr id
				if {[ispermban $ban]} {
					incr perm
				} else {
					incr nonperm
					if {[killban $ban]} {
						incr killed
						lappend unban "$ban"
					}
				}
			}
			if {$killed == "1"} {
				set x ban
			} else {
				set x bans
			}
			if {[llength $unban] > 0} {
				foreach c [channels] {
					foreach b $unban {
						if {$b == ""} { continue }
						pushmode $c -b $b
					}
					flushmode $c
				}
				putserv "NOTICE $nickname :Removed registered global tempban[expr {[llength $unban] > 1 ? "s" : ""}] \( [join $unban " "] \)."
			}
			putserv "NOTICE $nickname :I removed a total of $killed non-permanent $x (Total: $id Permanent: $perm Non-permanent: $nonperm)."
		}
	} elseif {[string equal -nocase all $option]} {
		set id "0"
		set perm "0"
		set nonperm "0"
		set killed "0"
		set perml [list]
		set nonperml [list]
		set chanbans "0"
		set chanbanl [list]
		foreach ban [chanbans $channel] {
			if {$ban == ""} { continue }
			set ban [lindex [split $ban] 0]
			if {![ispermban $ban $channel] && ![isban $ban $channel]} {
				incr chanbans 1
				lappend chanbanl "$ban"
			}
		}
		foreach ban [banlist $channel] {
			if {$ban == ""} { return }
			set ban [lindex $ban 0]
			incr id
			if {[ispermban $ban $channel]} {
				incr perm
				if {[killchanban $channel $ban]} {
					incr killed
				}
				lappend perml "$ban"
			} else {
				incr nonperm
				if {[killchanban $channel $ban]} {
					incr killed
				}
				lappend nonperml "$ban"
			}
		}
		if {[llength $perml] > 0} {
			putserv "NOTICE $nickname :Removed registered permban[expr {[llength $perml] > 1 ? "s" : ""}] \( [join $perml " "] \) from $channel."
			foreach ban $perml {
				if {$ban == ""} { continue }
				pushmode $channel -b $ban
			}
		}
		if {[llength $nonperml] > 0} {
			putserv "NOTICE $nickname :Removed registered tempban[expr {[llength $nonperml] > 1 ? "s" : ""}] \( [join $nonperml " "] \) from $channel."
			foreach ban $nonperml {
				if {$ban == ""} { continue }
				pushmode $channel -b $ban
			}
		}
		if {[llength $chanbanl] > 0} {
			putserv "NOTICE $nickname :Removed channel ban[expr {[llength $chanbanl] > 1 ? "s" : ""}] \( [join $chanbanl " "] \) from $channel."
			foreach ban $chanbanl {
				if {$ban == ""} { continue }
				pushmode $channel -b $ban
			}
		}
		flushmode $channel
		putserv "NOTICE $nickname :Total: [expr {$id + $chanbans}] (Permenant: $perm Non-permenant: $nonperm Channel bans: $chanbans)."
	} else {
		set id "0"
		set perm "0"
		set nonperm "0"
		set killed "0"
		set nonperml [list]
		set chanbans "0"
		set chanbanl [list]
		foreach ban [chanbans $channel] {
			if {$ban == ""} { continue }
			set ban [lindex [split $ban] 0]
			if {![ispermban $ban $channel] && ![isban $ban $channel]} {
				incr chanbans 1
				lappend chanbanl "$ban"
			}
		}
		foreach ban [banlist $channel] {
			if {$ban == ""} { return }
			set ban [lindex $ban 0]
			incr id
			if {[ispermban $ban $channel]} {
				incr perm
			} else {
				incr nonperm
				if {[killchanban $channel $ban]} {
					incr killed
				}
				lappend nonperml "$ban"
			}
		}
		if {[llength $nonperml] > 0} {
			putserv "NOTICE $nickname :Removed registered tempban[expr {[llength $nonperml] > 1 ? "s" : ""}] \( [join $nonperml " "] \) from $channel."
			foreach ban $nonperml {
				if {$ban == ""} { continue }
				pushmode $channel -b $ban
			}
		}
		if {[llength $chanbanl] > 0} {
			putserv "NOTICE $nickname :Removed channel ban[expr {[llength $chanbanl] > 1 ? "s" : ""}] \( [join $chanbanl " "] \) from $channel."
			foreach ban $chanbanl {
				if {$ban == ""} { continue }
				pushmode $channel -b $ban
			}
		}
		flushmode $channel
		putserv "NOTICE $nickname :Total: [expr {$id + $chanbans}] (Permenant: $perm Non-permenant: $nonperm Channel bans: $chanbans)."
	}
}
service::register {banclear bc} service::cmd_banclear

# say
proc service::cmd_say {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm|nmo $channel]} {
		puthelp "NOTICE $nickname :You have no access to this command."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	if {$text == ""} {
		putserv "NOTICE $nickname :SYNTAX: ${lastbind}$command <messaege>."
	} else {
		putserv "PRIVMSG $channel :$text"
	}
}
service::register say service::cmd_say

# saveop
proc service::cmd_saveop {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm|nm $channel]} {
		puthelp "NOTICE $nickname :You have no access to this command."
		return
	}
	service::track $handle "$channel ${lastbind}$command $text"
	set chan [string tolower $channel]
	switch -exact -- [string tolower [lindex [split $text] 0]] {
		"list" {
			set nicks [list]
			foreach key [array names service::saveops $chan:*] {
				lappend nicks [string range $key [string length $chan:] end]
			}
			putserv "NOTICE $nickname :Saved ops on $channel ([llength $nicks]): [expr {[llength $nicks] ? [join [lsort $nicks] ", "] : "none"}]."
			return
		}
		"clear" {
			array unset service::saveops $chan:*
			service::saveops_store $channel
			putserv "NOTICE $nickname :Saved op list for $channel cleared."
			return
		}
	}
	set count "0"
	foreach user [chanlist $channel] {
		if {![string equal -nocase $botnick $user] && [isop $user $channel] && $user != "Q" && $user != "L" && $user != "S" && ![info exists service::saveops($chan:[string tolower $user])]} {
			incr count 1
			set service::saveops($chan:[string tolower $user]) "1"
		}
	}
	service::saveops_store $channel
	putserv "NOTICE $nickname :Saved $count op(s) on $channel. A total of [llength [array names service::saveops $chan:*]] op(s) are saved for $channel (kept across restarts; '${lastbind}$command list|clear')."
}
service::register saveop service::cmd_saveop

# reop
proc service::cmd_reop {nickname hostname handle channel text lastbind command} {
	global botnick
	if {![matchattr $handle nm|nm $channel]} {
		puthelp "NOTICE $nickname :You have no access to this command."
		return
	}
	service::track $handle "$channel ${lastbind}$command"
	if {![botisop $channel]} {
		putserv "NOTICE $nickname :I need op to do that!"
		return
	}
	set count "0"
	set reop ""
	foreach user [chanlist $channel] {
		if {![string equal -nocase $botnick $user] && ![isop $user $channel] && $user != "Q" && $user != "L" && $user != "S" && [info exists service::saveops([string tolower $channel]:[string tolower $user])]} {
			lappend reop $user
			incr count 1
		}
		if {[llength $reop] == "6"} {
			putquick "MODE $channel +oooooo [join $reop " "]"
			set reop ""
		}
	}
	if {[llength $reop] != "0"} {
		putquick "MODE $channel +[string repeat "o" [llength $reop]] [join $reop " "]"
		set reop ""
	}
	putserv "NOTICE $nickname :Done. Restored $count op(s) on $channel. (The saved list is kept; use ${lastbind}saveop clear to empty it)"
}
service::register reop service::cmd_reop
