#!/usr/bin/env python3
"""Test PII redaction regex patterns from promtail-config.yml.

Extracts regex patterns directly from the config file (no YAML library needed)
and validates them against known test inputs using Python's re module.
"""
import re
import sys


def extract_patterns(config_path):
    """Extract 'expression:' values from promtail-config.yml.

    Parses single-quoted YAML string values without a YAML library.
    Returns patterns in file order: [IPv4, IPv6, Email].
    """
    patterns = []
    with open(config_path) as f:
        for line in f:
            stripped = line.strip()
            if stripped.startswith("expression:"):
                # expression: 'pattern' — extract single-quoted value
                value = stripped.split("'", 1)[1].rsplit("'", 1)[0]
                patterns.append(value)
    return patterns


def compile_pattern(pattern):
    """Compile regex, converting inline (?i) flags for Python compatibility.

    RE2 (Promtail/Go) allows (?i) per alternation branch; Python requires
    global flags at the pattern start only. Strip (?i) and use re.IGNORECASE.
    """
    flags = 0
    if "(?i)" in pattern:
        flags |= re.IGNORECASE
        pattern = pattern.replace("(?i)", "")
    return re.compile(pattern, flags)


def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <promtail-config.yml>")
        sys.exit(1)

    config_path = sys.argv[1]
    patterns = extract_patterns(config_path)

    if len(patterns) < 3:
        print(f"ERROR: Expected 3 regex patterns, found {len(patterns)}")
        sys.exit(1)

    ipv4_re = compile_pattern(patterns[0])
    ipv6_re = compile_pattern(patterns[1])
    email_re = compile_pattern(patterns[2])
    passed = 0
    failed = 0

    def assert_match(label, compiled_re, text):
        nonlocal passed, failed
        if compiled_re.search(text):
            print(f"  PASS: {label}")
            passed += 1
        else:
            print(f"  FAIL: {label} (expected match)")
            failed += 1

    def assert_no_match(label, compiled_re, text):
        nonlocal passed, failed
        if not compiled_re.search(text):
            print(f"  PASS: {label}")
            passed += 1
        else:
            print(f"  FAIL: {label} (unexpected match)")
            failed += 1

    print("=== IPv4 Redaction ===")
    assert_match("standard IP 192.168.1.1", ipv4_re, "Client 192.168.1.1 connected")
    assert_match("loopback 127.0.0.1", ipv4_re, "Listening on 127.0.0.1:8080")
    assert_match("boundary 255.255.255.255", ipv4_re, "Broadcast 255.255.255.255")
    assert_match("boundary 0.0.0.0", ipv4_re, "Bind 0.0.0.0:443")
    assert_match("Tailscale IP 100.100.1.2", ipv4_re, "Peer 100.100.1.2 up")
    assert_no_match("invalid octet 999.1.1.1", ipv4_re, "Addr 999.1.1.1")
    assert_no_match("invalid octet 1.256.1.1", ipv4_re, "Addr 1.256.1.1")
    assert_no_match("version string 1.2.3", ipv4_re, "version 1.2.3 released")

    print("\n=== IPv6 Redaction ===")
    assert_match("full IPv6", ipv6_re, "Addr 2001:0db8:85a3:0000:0000:8a2e:0370:7334")
    assert_match("abbreviated fe80::", ipv6_re, "Addr fe80::")
    assert_match("loopback ::1", ipv6_re, "Listen ::1")
    assert_match("mixed case", ipv6_re, "Addr FE80:0000:0000:0000:0000:0000:0000:0001")

    print("\n=== Email Redaction ===")
    assert_match("standard email", email_re, "User user@example.com logged in")
    assert_match("plus addressing", email_re, "From test+tag@domain.org")
    assert_match("subdomain email", email_re, "Contact admin@sub.domain.co.uk")
    assert_no_match("no TLD", email_re, "Value user@localhost")
    assert_no_match("plain text", email_re, "Hello world")

    print(f"\nResults: {passed} passed, {failed} failed")
    sys.exit(0 if failed == 0 else 1)


if __name__ == "__main__":
    main()
