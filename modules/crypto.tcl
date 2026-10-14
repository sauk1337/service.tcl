#####################################################################
# service.tcl - module: crypto
# SHA-256 and HMAC-SHA-256 (RFC 2104), used by Q CHALLENGEAUTH and by
# the updater to verify downloaded files. Uses tcllib's sha256 package
# when it is installed, otherwise a pure-Tcl implementation.
#####################################################################

namespace eval service::crypto {
	variable K {
		0x428a2f98 0x71374491 0xb5c0fbcf 0xe9b5dba5 0x3956c25b 0x59f111f1 0x923f82a4 0xab1c5ed5
		0xd807aa98 0x12835b01 0x243185be 0x550c7dc3 0x72be5d74 0x80deb1fe 0x9bdc06a7 0xc19bf174
		0xe49b69c1 0xefbe4786 0x0fc19dc6 0x240ca1cc 0x2de92c6f 0x4a7484aa 0x5cb0a9dc 0x76f988da
		0x983e5152 0xa831c66d 0xb00327c8 0xbf597fc7 0xc6e00bf3 0xd5a79147 0x06ca6351 0x14292967
		0x27b70a85 0x2e1b2138 0x4d2c6dfc 0x53380d13 0x650a7354 0x766a0abb 0x81c2c92e 0x92722c85
		0xa2bfe8a1 0xa81a664b 0xc24b8b70 0xc76c51a3 0xd192e819 0xd6990624 0xf40e3585 0x106aa070
		0x19a4c116 0x1e376c08 0x2748774c 0x34b0bcb5 0x391c0cb3 0x4ed8aa4a 0x5b9cca4f 0x682e6ff3
		0x748f82ee 0x78a5636f 0x84c87814 0x8cc70208 0x90befffa 0xa4506ceb 0xbef9a3f7 0xc67178f2
	}
	variable tcllib [expr {![catch {package require sha256}]}]
}

# Raw 32-byte SHA-256 digest of a byte string (every character must be 0-255).
proc service::crypto::digest {bytes} {
	variable tcllib
	if {$tcllib} {
		return [::sha2::sha256 -bin -- $bytes]
	}
	variable K
	set h0 0x6a09e667; set h1 0xbb67ae85; set h2 0x3c6ef372; set h3 0xa54ff53a
	set h4 0x510e527f; set h5 0x9b05688c; set h6 0x1f83d9ab; set h7 0x5be0cd19
	set len [string length $bytes]
	append bytes \x80 [string repeat \x00 [expr {(55 - $len) % 64}]] [binary format W [expr {$len * 8}]]
	set M 0xffffffff
	for {set off 0} {$off < [string length $bytes]} {incr off 64} {
		binary scan [string range $bytes $off [expr {$off + 63}]] Iu16 w
		for {set t 16} {$t < 64} {incr t} {
			set x [lindex $w [expr {$t - 15}]]
			set s0 [expr {((($x >> 7) | ($x << 25)) ^ (($x >> 18) | ($x << 14)) ^ ($x >> 3)) & $M}]
			set x [lindex $w [expr {$t - 2}]]
			set s1 [expr {((($x >> 17) | ($x << 15)) ^ (($x >> 19) | ($x << 13)) ^ ($x >> 10)) & $M}]
			lappend w [expr {([lindex $w [expr {$t - 16}]] + $s0 + [lindex $w [expr {$t - 7}]] + $s1) & $M}]
		}
		set a $h0; set b $h1; set c $h2; set d $h3; set e $h4; set f $h5; set g $h6; set h $h7
		for {set t 0} {$t < 64} {incr t} {
			set S1 [expr {((($e >> 6) | ($e << 26)) ^ (($e >> 11) | ($e << 21)) ^ (($e >> 25) | ($e << 7))) & $M}]
			set ch [expr {($e & $f) ^ (~$e & $g & $M)}]
			set t1 [expr {($h + $S1 + $ch + [lindex $K $t] + [lindex $w $t]) & $M}]
			set S0 [expr {((($a >> 2) | ($a << 30)) ^ (($a >> 13) | ($a << 19)) ^ (($a >> 22) | ($a << 10))) & $M}]
			set maj [expr {($a & $b) ^ ($a & $c) ^ ($b & $c)}]
			set h $g; set g $f; set f $e
			set e [expr {($d + $t1) & $M}]
			set d $c; set c $b; set b $a
			set a [expr {($t1 + $S0 + $maj) & $M}]
		}
		set h0 [expr {($h0 + $a) & $M}]; set h1 [expr {($h1 + $b) & $M}]
		set h2 [expr {($h2 + $c) & $M}]; set h3 [expr {($h3 + $d) & $M}]
		set h4 [expr {($h4 + $e) & $M}]; set h5 [expr {($h5 + $f) & $M}]
		set h6 [expr {($h6 + $g) & $M}]; set h7 [expr {($h7 + $h) & $M}]
	}
	return [binary format I8 [list $h0 $h1 $h2 $h3 $h4 $h5 $h6 $h7]]
}

proc service::crypto::hex {bytes} {
	binary scan $bytes H* hex
	return $hex
}

# SHA-256 of a text string (UTF-8 encoded), as lowercase hex.
proc service::crypto::sha256 {text} {
	return [hex [digest [encoding convertto utf-8 $text]]]
}

# SHA-256 of a file's raw contents, as lowercase hex.
proc service::crypto::sha256_file {path} {
	set fh [open $path rb]
	set bytes [read $fh]
	close $fh
	return [hex [digest $bytes]]
}

# HMAC-SHA-256 (RFC 2104) of a text message with a text key, as lowercase hex.
proc service::crypto::hmac_sha256 {key message} {
	set key [encoding convertto utf-8 $key]
	if {[string length $key] > 64} {
		set key [digest $key]
	}
	append key [string repeat \x00 [expr {64 - [string length $key]}]]
	set ipad ""; set opad ""
	foreach v [split $key ""] {
		scan $v %c v
		append ipad [format %c [expr {$v ^ 0x36}]]
		append opad [format %c [expr {$v ^ 0x5c}]]
	}
	set inner [digest "$ipad[encoding convertto utf-8 $message]"]
	return [hex [digest "$opad$inner"]]
}
