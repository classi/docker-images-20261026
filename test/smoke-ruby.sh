#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "usage: $0 IMAGE EXPECTED_RUBY_VERSION" >&2
  exit 2
fi

image="$1"
expected_version="$2"
failures=0

check() {
  local name="$1"
  shift
  if docker run --rm "$image" "$@" >/dev/null 2>&1; then
    echo "ok   - $name"
  else
    echo "FAIL - $name"
    failures=$((failures + 1))
  fi
}

check "ruby version is $expected_version" ruby -e "exit RUBY_VERSION == '$expected_version'"
check "libruby is shared" ruby -e 'exit RbConfig::CONFIG["ENABLE_SHARED"] == "yes"'
check "yjit is available" ruby --yjit -e 'exit RubyVM::YJIT.enabled?'
if [ "${expected_version%%.*}" -ge 4 ]; then
  check "zjit is available" ruby --zjit -e 'exit RubyVM::ZJIT.enabled?'
else
  echo "skip - zjit (Ruby < 4.0)"
fi
check "openssl 3 is linked" ruby -ropenssl -e 'exit OpenSSL::OPENSSL_LIBRARY_VERSION.start_with?("OpenSSL 3")'
check "psych is linked to libyaml" ruby -rpsych -e 'exit !Psych::LIBYAML_VERSION.empty?'
check "zlib works" ruby -rzlib -e 'exit Zlib.inflate(Zlib.deflate("ok")) == "ok"'
check "bundler is installed" bundle --version
check "GEM_HOME is /usr/local/bundle" sh -c 'test "$GEM_HOME" = /usr/local/bundle'
check "no ruby package from apt" sh -c '! dpkg -l | grep -qi ruby'

if [ "$failures" -gt 0 ]; then
  echo "$failures check(s) failed" >&2
  exit 1
fi
