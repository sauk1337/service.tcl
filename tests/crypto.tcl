# Verifies modules/crypto.tcl against published test vectors.
# Usage: tclsh tests/crypto.tcl
source -encoding utf-8 [file join [file dirname [info script]] .. modules crypto.tcl]
set fails 0
proc check {name got want} {
	if {$got eq $want} { puts "ok   $name" } else { puts "FAIL $name\n     got  $got\n     want $want"; incr ::fails }
}
# FIPS 180-2
check "sha256 empty" [service::crypto::sha256 ""] e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
check "sha256 abc" [service::crypto::sha256 abc] ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
check "sha256 448 bits" [service::crypto::sha256 abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq] 248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1
check "sha256 1M a" [service::crypto::sha256 [string repeat a 1000]] 41edece42d63e8d9bf515a9ba6932e1c20cbc9f5a5d134645adb5db1b9737ea3
# RFC 4231 test case 2
check "hmac rfc4231 #2" [service::crypto::hmac_sha256 Jefe "what do ya want for nothing?"] 5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843
# QuakeNet CHALLENGEAUTH HMAC-SHA-256 test vectors
proc qresponse {lcuser truncpass challenge} {
	set key [service::crypto::sha256 "$lcuser:[service::crypto::sha256 $truncpass]"]
	return [service::crypto::hmac_sha256 $key $challenge]
}
check "Q mooking" [qresponse mooking 0000000000 12345678901234567890123456789012] f6eced34321a69c270472d06c50e959c48e9fd323b2c5d3194f44b50a118a7ea
check "Q fishking" [qresponse fishking ZZZZZZZZZZ 12345678901234567890123456789012] 504056d53b2fc4fd783dc4f086dabc59f845d201e650b96dfa95dacc8cac2892
puts "tcllib: $service::crypto::tcllib - failures: $fails"
if {$fails} { exit 1 }
