# Functional tests for CHALLENGEAUTH, auth-before-join, takeover protection,
# Q commands, accounts, saveop persistence, help and botnet requests.
# Usage: tclsh tests/features.tcl
set here [file dirname [info script]]
source [file join $here mock.tcl]
set ::timers {}
proc utimer {secs cmd} { lappend ::timers $cmd; return "timer[llength $::timers]" }
proc run_timers {} { set t $::timers; set ::timers {}; foreach c $t { uplevel #0 $c } }
source -encoding utf-8 [file join $here .. service.tcl]

set fails 0
proc check {name cond} {
	if {[uplevel 1 [list expr $cond]]} { puts "ok   $name" } else { puts "FAIL $name"; incr ::fails }
}
proc sent_match {pattern} {
	foreach l $::sent { if {[string match $pattern $l]} { return 1 } }
	return 0
}
proc say {nick text {hand owner} {host owner@owner.users.quakenet.org}} {
	service::central $nick $host $hand #test $text
}
set ::xtra(owner,mytrigger) !

# --- CHALLENGEAUTH + auth before join -------------------------------------
set service::qauth(user) {[FishKing]}
set service::qauth(pass) iLOVEfish12345
set ::chanset(#test,inactive) 0
set ::sent {}
service::qauth 1
check "challenge requested" {[sent_match "PRIVMSG Q@CServe.quakenet.org :CHALLENGE"]}
check "channel held while authing" {$::chanset(#test,inactive) == 1 && [file exists [service::qauth_heldfile]]}
set ::sent {}
service::qnotice Q TheQBot@CServe.quakenet.org * "CHALLENGE 3afabede5c2859fd821e315f889d9a6c HMAC-MD5 HMAC-SHA-1 HMAC-SHA-256 LEGACY-MD5"
set expected [service::crypto::hmac_sha256 [service::crypto::sha256 "{fishking}:[service::crypto::sha256 iLOVEfish1]"] 3afabede5c2859fd821e315f889d9a6c]
check "CHALLENGEAUTH sent with correct HMAC-SHA-256" {[lsearch -exact $::sent "PRIVMSG Q@CServe.quakenet.org :CHALLENGEAUTH \[FishKing\] $expected HMAC-SHA-256"] != -1}
check "password never sent" {![sent_match "*iLOVEfish*"]}
set ::sent {}
service::qnotice Fake fake@evil.com * "You are now logged in as FishKing."
check "spoofed Q notice ignored" {$service::qauth_state eq "authing"}
service::qnotice Q TheQBot@CServe.quakenet.org * "You are now logged in as FishKing."
check "logged in" {$service::qauth_state eq "authed"}
check "+x set" {[sent_match "MODE TestBot +x"]}
run_timers
check "channel released after auth" {$::chanset(#test,inactive) == 0 && ![file exists [service::qauth_heldfile]]}

# --- Q commands + relay ----------------------------------------------------
set ::sent {}
say Owner "!qban Bob 2h flooding"
check "qban -> Q TEMPBAN" {[sent_match "PRIVMSG Q :TEMPBAN #test *!*user@host.example.com 2h flooding"]}
say Owner "!qrecover"
check "qrecover -> Q RECOVER" {[sent_match "PRIVMSG Q :RECOVER #test"]}
set ::sent {}
service::qnotice Q TheQBot@CServe.quakenet.org * "Done."
check "Q answer relayed to the user" {[sent_match "NOTICE owner :\\\[Q\\\] Done."]}
set ::sent {}
say Owner "!qban TestBot"
check "qban refuses the bot itself" {![sent_match "*TEMPBAN*"]}

# --- takeover --------------------------------------------------------------
set ::chanset(#test,service_prot) 1
set ::sent {}
foreach v {A B C} {
	service::tk_mode Evil!evil@attacker.users.quakenet.org MODE "#test -o $v"
}
check "takeover: attacker kick-banned" {[sent_match "MODE #test -o+b Evil *!*@attacker.users.quakenet.org"] && [sent_match "KICK #test Evil :Takeover protection*"]}
check "takeover: Q RECOVER + OP" {[sent_match "PRIVMSG Q :RECOVER #test"] && [sent_match "PRIVMSG Q :OP #test"]}
check "takeover: Q TEMPBAN" {[sent_match "PRIVMSG Q :TEMPBAN #test *!*@attacker.users.quakenet.org 1h *"]}
check "takeover: Q CHANLEV removal" {[sent_match "PRIVMSG Q :CHANLEV #test #attacker -aogvt"]}
check "takeover: lockdown +im" {[sent_match "MODE #test +im"] && [string match "im *" $::chanset(#test,service_lockdown)]}
check "takeover: staff alerted" {[sent_match "PRIVMSG #yourchannel.staff :*TAKEOVER*"]}
set ::sent {}
service::tk_mode Op2!op2@x.users.quakenet.org MODE "#test -o A"
service::tk_mode Op2!op2@x.users.quakenet.org MODE "#test -o B"
check "2 deops: no reaction (threshold 3)" {![sent_match "*RECOVER*"]}
set ::sent {}
service::tk_mode Self!s@s.users.quakenet.org MODE "#test -o Self"
service::tk_mode Self!s@s.users.quakenet.org MODE "#test -o Self"
service::tk_mode Self!s@s.users.quakenet.org MODE "#test -o Self"
check "self-deops don't count" {![sent_match "*RECOVER*"]}
set ::sent {}
proc finduser {mask} { expr {[string match *@owner.users.quakenet.org $mask] ? "owner" : "*"} }
foreach v {A B C} { service::tk_mode Owner!owner@owner.users.quakenet.org MODE "#test -o $v" }
check "exempt owner: no action" {![sent_match "*RECOVER*"] && ![sent_match "KICK #test Owner*"]}
set ::sent {}
say Owner "!lockdown off"
check "lockdown off removes only our modes" {[sent_match "MODE #test -im"] && $::chanset(#test,service_lockdown) eq ""}

# --- mode/kick/topic protection ----------------------------------------------
set ::chanset(#test,service_prot) 1
proc finduser {mask} { expr {[string match *@owner.users.quakenet.org $mask] ? "owner" : "*"} }
proc nick2hand {nick args} { expr {[string equal -nocase $nick Owner] ? "owner" : "*"} }
proc getchanmode {chan} { return "+ntkl secret 50" }
set ::sent {}
service::modeprot Evil!evil@evil.users.quakenet.org MODE "#test +o TestBot"
check "modeprot: op given to the bot is not undone" {![sent_match "*-o*TestBot*"]}
set ::sent {}
service::modeprot Evil!evil@evil.users.quakenet.org MODE "#test -k+o secret Friend"
check "modeprot: -k restored with the old key, params aligned" {[sent_match "MODE #test +k-o secret Friend"]}
check "modeprot: attacker kick-banned" {[sent_match "MODE #test -o+b Evil *!*@evil.users.quakenet.org"] && [sent_match "KICK #test Evil *"]}
set ::sent {}
service::modeprot Evil!evil@evil.users.quakenet.org MODE "#test -l+imr"
check "modeprot: -l restored, QuakeNet modes reverted" {[sent_match "MODE #test +l-imr 50"]}
set ::sent {}
service::modeprot Evil!evil@evil.users.quakenet.org MODE "#test +oooooooo a b c d e f g h"
check "modeprot: max 6 modes per line" {[sent_match "MODE #test -oooooo a b c d e f"] && [sent_match "MODE #test -oo g h"]}
set ::sent {}
service::modeprot Evil!evil@evil.users.quakenet.org MODE "#test -o TestBot"
check "modeprot: bot deopped -> Q RECOVER/UNBANME/OP" {[sent_match "PRIVMSG Q :RECOVER #test"] && [sent_match "PRIVMSG Q :OP #test"]}
set ::sent {}
service::modeprot Owner!owner@owner.users.quakenet.org MODE "#test +im"
check "modeprot: known users are not punished" {![sent_match "KICK*"] && ![sent_match "MODE #test -im"]}
set ::sent {}
service::modeprot Q!TheQBot@CServe.quakenet.org MODE "#test +b *!*@x"
service::topicprot Q!TheQBot@CServe.quakenet.org TOPIC "#test :Set by Q"
check "Q is never punished (modes / topic)" {![sent_match "*Q*CServe*"] && ![sent_match "KICK #test Q*"]}
set ::sent {}
service::topicprot Evil!evil@evil.users.quakenet.org TOPIC "#test :pwned: by evil"
check "topicprot: unknown topic change kick-banned" {[sent_match "KICK #test Evil *"]}
set ::chanset(#test,service_enforcemodes) 1
set ::chanset(#test,service_enforcedmodes) "+nt-i"
set ::sent {}
service::modeprot Owner!owner@owner.users.quakenet.org MODE "#test +i"
check "enforcemodes: undone even for known users" {[sent_match "MODE #test -i"]}
set ::chanset(#test,service_enforcemodes) 0
proc getchanmode args { return "+nt" }

# --- this round's fixes -------------------------------------------------------
# clonescan enabled with chanflags only (maxclones never set) must not kick everyone
array unset ::chanset #test,service_clonescan_*
set ::chanset(#test,service_clonescan) 1
proc chanlist args { return {Owner TestBot Q Bob} }
proc getchanhost {nick args} { return "~u@[string tolower $nick].example.com" }
set ::sent {}
service::onjoin_clonescan Bob ~u@bob.example.com * #test
check "clonescan: default maxclones, no kick for a single user" {![sent_match "KICK*"] && $::chanset(#test,service_clonescan_maxclones) == 5}
proc getchanhost {nick args} { return "~u@same.example.com" }
proc chanlist args { return {A B C D E F TestBot} }
set ::sent {}
service::onjoin_clonescan F ~u@same.example.com * #test
check "clonescan: 6 clones kicked (max 5)" {[sent_match "KICK #test F *"] && [sent_match "MODE #test +b *!*@same.example.com"]}
set ::chanset(#test,service_clonescan) 0
proc getchanhost args { return ~user@host.example.com }
proc chanlist args { return {Owner TestBot Q Bob} }

# autolimit: any difference of 2+ updates the limit (was: exactly 3)
set ::chanset(#test,service_autolimit) 1
set ::chanset(#test,service_limit) 10
proc getchanmode args { return "+ntl 5" }
set ::pm {}
proc pushmode {channel mode {arg ""}} { lappend ::pm "$mode $arg" }
service::autolimit_update #test
check "autolimit: stuck limit (5 for 4 users) raised to 14" {[lsearch -exact $::pm "+l 14"] != -1}
set ::chanset(#test,service_autolimit) 0
proc getchanmode args { return "+nt" }

# spamscan: adverts are detected again (caps check used to destroy the word)
set ::chanset(#test,service_spamscan) 1
array unset ::service::spam *
service::spamscan Spammer sp@spam.example.com * #test "join www.spam-site.com now"
check "spamscan: advert detected" {[info exists ::service::spam(points:#test:*!*sp@spam.example.com)] && $::service::spam(points:#test:*!*sp@spam.example.com) >= 15}
set ::chanset(#test,service_spamscan) 0
check "parseflud: Eggdrop's own flood protection kept when service flood is off" {[service::parseflud X x@y * pub #test] == 0}

# adduser can't take over an existing handle
proc validuser h { expr {$h in {owner other}} }
proc nick2hand {nick args} { expr {[string equal -nocase $nick Owner] ? "owner" : "*"} }
set ::sent {}
say Owner "!adduser Bob other op"
check "adduser: existing handle refused" {[sent_match "*Handle 'other' already exists*"]}

# peak
set ::chanset(#test,service_peak) 1
set ::chanset(#test,service_peak_count) 2
set ::sent {}
service::onjoin_peak Bob x@y * #test
check "peak: new record announced" {$::chanset(#test,service_peak_count) == 4 && [sent_match "PRIVMSG #test :New user record*"]}
set ::chanset(#test,service_peak) 0

# enforcemodes command
set ::sent {}
say Owner "!enforcemodes +ntk"
check "enforcemodes: +k without key refused" {[sent_match "*+k needs a parameter*"]}
say Owner "!enforcemodes +nti"
check "enforcemodes: set and applied" {$::chanset(#test,service_enforcedmodes) eq "+nti" && [sent_match "MODE #test +i"]}
say Owner "!enforcemodes off"

# --- accounts --------------------------------------------------------------
set ::sent {}
say Owner "!account #owner SaukAcct"
check "account linked" {$::xtra(owner,account) eq "SaukAcct" && [service::resolve Stranger *] eq "*"}
proc getaccount {nick} { expr {$nick eq "Stranger" ? "saukacct" : ""} }
check "user recognised by Q account" {[service::resolve Stranger *] eq "owner"}
rename getaccount ""

# --- saveop persistence ------------------------------------------------------
proc isop {nick chan} { expr {$nick eq "Bob"} }
say Owner "!saveop"
check "saveop stored in channel setting" {[string match "*bob*" $::chanset(#test,service_saveops)]}
array unset ::service::saveops
service::saveops_load
check "saveop list reloaded after restart" {[info exists ::service::saveops(#test:bob)]}
proc isop args { return 0 }

# --- help --------------------------------------------------------------------
set ::sent {}
say Owner "!help qban"
check "help qban shows syntax" {[sent_match "NOTICE Owner :*!qban* <nickname|mask>*"] && [sent_match "*Aliases: qtempban*"]}
set ::sent {}
say Owner "!help"
check "help lists categories" {[sent_match "NOTICE Owner :*Q:*qban*"]}

# --- botnet ------------------------------------------------------------------
set service::botnet(enabled) 1
proc validuser h { expr {$h in {owner Bot2}} }
proc matchattr {h f args} { expr {$h eq "owner" || ($h eq "Bot2" && ([string match "*b*" $f] || [string match "*o*" $f]))} }
proc getuser {h type args} {
	if {$h eq "Bot2" && $type eq "HOSTS"} { return {*!bot2@bot2.example.com} }
	if {![validuser $h]} { error "No such user." }
	if {$type eq "XTRA"} { set k $h,[lindex $args 0]; return [expr {[info exists ::xtra($k)] ? $::xtra($k) : ""}] }
	return ""
}
proc isop {nick chan} { return 0 }
set ::sent {}
service::botnet_onneed Bot2 svc_need "op #test Bot2!bot2@bot2.example.com"
check "botnet: ops a verified partner bot" {[sent_match "MODE #test +o Bot2"]}
set ::sent {}
service::botnet_onneed Bot2 svc_need "op #test Evil!evil@attacker.com"
check "botnet: refuses a nick that isn't the bot" {![sent_match "MODE #test +o*"]}
set ::sent {}
service::botnet_onneed Stranger svc_need "op #test Stranger!x@y"
check "botnet: refuses untrusted bots" {![sent_match "MODE #test +o*"]}

# --- auto login on connect ---------------------------------------------------
# Eggdrop matches evnt binds against the event name exactly (MATCH_EXACT),
# so a "*" mask never fires.
proc fire_evnt {event} {
	foreach b $::mockbinds {
		lassign $b type flags mask cmd
		if {$type eq "evnt" && $mask eq $event} { uplevel #0 [list {*}$cmd $event] }
	}
}
set wild 0
foreach b $::mockbinds { if {[lindex $b 0] eq "evnt" && [string match {*[*?]*} [lindex $b 2]]} { incr wild } }
check "no wildcard evnt binds" {$wild == 0}
set service::qauth_state idle
set ::sent {}
fire_evnt init-server
check "init-server starts the Q login" {[sent_match "PRIVMSG Q@CServe.quakenet.org :CHALLENGE"] && $service::qauth_state eq "challenge"}
run_timers
set service::qauth_state idle
set ::sent {}
set ::server-online [clock seconds]
set ::botname TestBot!bot@1.2.3.4
service::qauth_onload
check "login when loaded while already connected" {[sent_match "PRIVMSG Q@CServe.quakenet.org :CHALLENGE"]}
set service::qauth_state idle
set ::sent {}
set ::botname TestBot!bot@test.users.quakenet.org
service::qauth_onload
check "no login when already authed (+x)" {![sent_match "*CHALLENGE*"] && $service::qauth_state eq "authed"}
run_timers

# --- adduser: Q auth host ------------------------------------------------------
# small user store for these tests
array set ::uhosts {owner {*!*@owner.users.quakenet.org} newbie {*!*user@1.2.3.4}}
proc validuser h { info exists ::uhosts($h) }
proc getuser {h type args} {
	if {![validuser $h]} { error "No such user." }
	if {$type eq "HOSTS"} { return $::uhosts($h) }
	if {$type eq "XTRA"} { set k $h,[lindex $args 0]; return [expr {[info exists ::xtra($k)] ? $::xtra($k) : ""}] }
	return ""
}
proc setuser {h type args} {
	if {$type eq "HOSTS"} { lappend ::uhosts($h) [lindex $args 0] }
	if {$type eq "XTRA"} { set ::xtra($h,[lindex $args 0]) [lindex $args 1] }
}
proc userlist args { array names ::uhosts }
check "auth host added" {[service::add_authhost newbie someaccount] eq "*!*@someaccount.users.quakenet.org" && "*!*@someaccount.users.quakenet.org" in $::uhosts(newbie)}
check "account linked" {$::xtra(newbie,account) eq "someaccount"}
check "auth host not duplicated" {[service::add_authhost newbie SomeAccount] eq "" && [llength $::uhosts(newbie)] == 2}
check "invalid account ignored" {[service::add_authhost newbie {bad name}] eq ""}
# user without +x: account comes from WHOIS 330
set ::uhosts(newbie2) {*!*user@5.6.7.8}
set ::sent {}
service::adduser_authhost newbie2 Newbie2 Owner
check "WHOIS sent for user without +x" {[sent_match "WHOIS Newbie2"]}
service::acctlookup_raw irc.quakenet.org 330 "TestBot Newbie2 nb2 :is authed as"
service::acctlookup_raw irc.quakenet.org 318 "TestBot Newbie2 :End of /WHOIS list."
check "auth host added from WHOIS" {"*!*@nb2.users.quakenet.org" in $::uhosts(newbie2) && [sent_match "NOTICE Owner :Also added Q auth host*"]}
set ::uhosts(newbie3) {*!*user@9.9.9.9}
set ::sent {}
service::adduser_authhost newbie3 Newbie3 Owner
service::acctlookup_raw irc.quakenet.org 318 "TestBot Newbie3 :End of /WHOIS list."
check "not authed: only hostmask, adder told" {[llength $::uhosts(newbie3)] == 1 && [sent_match "*Newbie3 is not authed with Q*"]}

puts "failures: $fails"
if {$fails} { exit 1 }
