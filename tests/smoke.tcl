# Smoke test: loads service.tcl with simulated Eggdrop commands, compiles every
# proc and runs every command through the dispatcher.
# Usage: tclsh tests/smoke.tcl [path/to/service.tcl]

source [file join [file dirname [info script]] mock.tcl]
if {[catch {source -encoding utf-8 [expr {[llength $argv] ? [lindex $argv 0] : [file join [file dirname [info script]] .. service.tcl]}]} err]} { puts "LOAD ERROR: $err\n$::errorInfo"; exit 1 }
set bad 0
foreach m $::service::modules {
	if {$m ni $::service::loadedmodules} { puts "MODULE NOT LOADED: $m"; incr bad }
}
foreach ns {::service} {
	foreach p [lsort [info procs ${ns}::*]] {
		if {[catch {tcl::unsupported::disassemble proc $p} e]} { puts "COMPILE $p: $e"; incr bad }
	}
}
puts "procs: [llength [info procs ::service::*]] + cmds: [llength [info procs ::service::cmd_*]] / registered names: [array size ::service::cmdmap] / compile errors: $bad"
# run every command with no args and with some args, as owner, via the dispatcher
set ::xtra(owner,mytrigger) !
set fails 0
foreach name [lsort [array names ::service::cmdmap]] {
	if {$name in {tcl}} continue
	foreach a [list "" "status" "Bob" "on" "list" "#1" "*!*@bad.example.com" "all" "-global" "-global all" "off" "set bantime #5" "add #bad" "del #bad" "+psC" "Bob 1h test [format %c 123]brace" "*"] {
		set ::sent {}
		if {[catch {service::central Owner owner@owner.users.quakenet.org owner #test "!$name $a"} e]} {
			puts "RUNTIME !$name $a -> $e"; incr fails
		}
	}
}
# filters / unknown users / botnick form
foreach line [list "hello [format %c 123]world" "!op" "TestBot version" "WWW.SPAM.COM join #other"] {
	if {[catch {service::central Bob bob@x.com * #test $line} e]} { puts "RUNTIME filter '$line' -> $e"; incr fails }
}
puts "runtime failures: $fails"
set ::xtra(owner,mytrigger) !; array unset ::chanset; foreach line {"!version" "!protect on" "!protect status" "TestBot op Bob" "!kick Bob go away" "$version"} {
	set ::sent {}
	service::central Owner owner@owner.users.quakenet.org owner #test $line
	puts "$line => [join $::sent { | }]"
}

if {$bad || $fails} { exit 1 }
