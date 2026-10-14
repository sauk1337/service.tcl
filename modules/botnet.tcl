#####################################################################
# service.tcl - module: botnet
# Mutual protection between linked Eggdrop bots that run service.tcl:
#  - a bot that needs op / invite / unban / key / limit on a channel asks
#    its linked partner bots, which help if they are opped there
#  - a takeover detected by one bot is announced to the others, which
#    kick-ban the attacker too
# A request is only accepted from a linked bot whose handle has the bot
# flag (+b) and the configured trust flag (default +o, global or for the
# channel), and only for the nickname that matches that bot's hostmasks.
# Disabled unless botnet(enabled) is 1 in service.conf.
#####################################################################

namespace eval service {
	bind need - {*} [namespace current]::botnet_need
	bind bot - {svc_need} [namespace current]::botnet_onneed
	bind bot - {svc_key} [namespace current]::botnet_onkey
	bind bot - {svc_takeover} [namespace current]::botnet_ontakeover
}

proc service::botnet_enabled {} {
	return [expr {[service::cfg botnet enabled 0] && [llength [bots]] > 0}]
}

# Is this linked bot allowed to ask for help on the channel?
proc service::botnet_trusted {frombot channel} {
	if {![validuser $frombot] || ![matchattr $frombot b]} { return 0 }
	set flag [service::cfg botnet flag o]
	return [matchattr $frombot $flag|$flag $channel]
}

# need-op / need-invite / need-unban / need-key / need-limit
proc service::botnet_need {channel type} {
	if {![service::botnet_enabled]} { return 0 }
	set me "$::botnick![lindex [split $::botname !] 1]"
	putallbots "svc_need $type $channel $me"
	return 0
}

proc service::botnet_onneed {frombot command text} {
	if {![service::cfg botnet enabled 0]} { return }
	lassign [split $text] type channel requester
	if {![validchan $channel] || ![botonchan $channel]} { return }
	if {![service::botnet_trusted $frombot $channel]} {
		putlog "service.tcl - botnet: ignored '$type' request for $channel from untrusted bot $frombot"
		return
	}
	set rnick [lindex [split $requester !] 0]
	# the requester must really be that bot: its address has to match one of
	# the hostmasks stored for the bot's handle
	set verified 0
	foreach mask [getuser $frombot HOSTS] {
		if {[string match -nocase $mask $requester]} { set verified 1; break }
	}
	if {!$verified} {
		putlog "service.tcl - botnet: $frombot asked '$type' on $channel as $requester, which doesn't match its hostmasks - ignored"
		return
	}
	switch -exact -- $type {
		"op" {
			if {[botisop $channel] && [onchan $rnick $channel] && ![isop $rnick $channel]} {
				service::now "MODE $channel +o $rnick"
			}
		}
		"invite" {
			if {[botisop $channel] && ![onchan $rnick $channel]} {
				putquick "INVITE $rnick $channel"
			}
		}
		"unban" {
			if {[botisop $channel]} {
				foreach ban [chanbans $channel] {
					set mask [lindex $ban 0]
					if {[string match -nocase $mask $requester]} {
						pushmode $channel -b $mask
					}
				}
				flushmode $channel
				putquick "INVITE $rnick $channel"
			}
		}
		"limit" {
			if {[botisop $channel]} {
				pushmode $channel +l [expr {[llength [chanlist $channel]] + 2}]
				flushmode $channel
				putquick "INVITE $rnick $channel"
			}
		}
		"key" {
			set modes [split [getchanmode $channel]]
			if {[string match "*k*" [lindex $modes 0]]} {
				# the key is only sent over the botnet to a verified, trusted bot
				putbot $frombot "svc_key $channel [lindex $modes 1]"
			}
		}
	}
}

proc service::botnet_onkey {frombot command text} {
	if {![service::cfg botnet enabled 0]} { return }
	lassign [split $text] channel key
	if {[validchan $channel] && ![botonchan $channel] && [service::botnet_trusted $frombot $channel]} {
		putquick "JOIN $channel $key"
	}
}

# Called by the takeover module when this bot detects an attack.
proc service::botnet_alert {channel nickname userhost why} {
	if {![service::botnet_enabled] || ![service::cfg botnet share_takeover 1]} { return }
	putallbots "svc_takeover $channel $nickname!$userhost $why"
}

proc service::botnet_ontakeover {frombot command text} {
	if {![service::cfg botnet enabled 0] || ![service::cfg botnet share_takeover 1]} { return }
	set words [split $text]
	set channel [lindex $words 0]
	set who [lindex $words 1]
	if {![validchan $channel] || ![service::botnet_trusted $frombot $channel]} { return }
	set nickname [lindex [split $who !] 0]
	set userhost [lindex [split $who !] 1]
	set handle [service::resolve $nickname [finduser $who]]
	if {[matchattr $handle [service::cfg takeover exempt "bn|n"] $channel]} { return }
	set mask [service::banmask $userhost]
	putlog "service.tcl - botnet: $frombot reports a takeover on $channel by $who"
	if {[botisop $channel]} {
		if {[onchan $nickname $channel]} {
			service::now "MODE $channel -o+b $nickname $mask"
			service::now "KICK $channel $nickname :Takeover protection (reported by $frombot)"
		} else {
			service::now "MODE $channel +b $mask"
		}
	}
	newchanban $channel $mask $::botnick "Takeover protection (reported by $frombot)" [service::cfg takeover ban_time 120]
}
