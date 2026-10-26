#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 3 ]; then
  echo "usage: $0 IMAGE EXPECTED_PHP_VERSION VARIANT(cli|fpm|apache)" >&2
  exit 2
fi

image="$1"
expected_version="$2"
variant="$3"
failures=0

case "$variant" in
  cli|fpm|apache) ;;
  *)
    echo "unknown variant: $variant" >&2
    exit 2
    ;;
esac

check() {
  local name="$1"
  shift
  if docker run --rm "$@" >/dev/null 2>&1; then
    echo "ok   - $name"
  else
    echo "FAIL - $name"
    failures=$((failures + 1))
  fi
}

check "php version is $expected_version" "$image" php -r "exit(PHP_VERSION === '$expected_version' ? 0 : 1);"

for ext in openssl sodium mbstring curl zlib xml pdo; do
  check "$ext extension is loaded" "$image" php -r "exit(extension_loaded('$ext') ? 0 : 1);"
done

check "openssl 3 is linked" "$image" php -r 'exit(str_starts_with(OPENSSL_VERSION_TEXT, "OpenSSL 3") ? 0 : 1);'
check "docker-php-ext-install works offline" --network none "$image" \
  sh -c 'docker-php-ext-install bcmath && php -r "exit(extension_loaded(\"bcmath\") ? 0 : 1);"'
check "pecl is installed" "$image" pecl version
check "no php package from apt" "$image" sh -c '! dpkg -l | grep -qE "^ii +php"'

case "$variant" in
  fpm)
    check "php-fpm config is valid" "$image" php-fpm -t
    ;;
  apache)
    check "apache loads php_module" "$image" sh -c 'apache2ctl -M 2>/dev/null | grep -q php_module'
    ;;
esac

if [ "$failures" -gt 0 ]; then
  echo "$failures check(s) failed" >&2
  exit 1
fi
