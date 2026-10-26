variable "REGISTRY_IMAGES" {
  type    = list(string)
  default = ["ghcr.io/classi/php"]
}

variable "PHP_VERSION" {
  validation {
    condition     = can(regex("^8\\.[2345]\\.[0-9]+$", PHP_VERSION))
    error_message = "PHP_VERSION must be 8.2.x, 8.3.x, 8.4.x or 8.5.x"
  }
}

variable "PHP_SHA256" {
  validation {
    condition     = can(regex("^[0-9a-f]{64}$", PHP_SHA256))
    error_message = "PHP_SHA256 must be 64 lowercase hex characters"
  }
}

function "minor" {
  params = [version]
  result = regex("^([0-9]+\\.[0-9]+)\\.", version)[0]
}

function "tag" {
  params = [image, version, suffix]
  result = suffix == "" ? "${image}:${version}" : "${image}:${version}-${suffix}"
}

group "default" {
  targets = ["php"]
}

target "php" {
  name = "php-${item.variant}-${item.distro}"
  matrix = {
    item = [
      { variant = "cli", distro = "trixie", suffixes = ["cli-trixie", "trixie", "cli", ""] },
      { variant = "cli", distro = "bookworm", suffixes = ["cli-bookworm", "bookworm"] },
      { variant = "fpm", distro = "trixie", suffixes = ["fpm-trixie", "fpm"] },
      { variant = "fpm", distro = "bookworm", suffixes = ["fpm-bookworm"] },
      { variant = "apache", distro = "trixie", suffixes = ["apache-trixie", "apache"] },
      { variant = "apache", distro = "bookworm", suffixes = ["apache-bookworm"] },
    ]
  }
  context = "php/${minor(PHP_VERSION)}/${item.distro}/${item.variant}"
  args = {
    PHP_VERSION = PHP_VERSION
    PHP_URL     = "https://www.php.net/distributions/php-${PHP_VERSION}.tar.xz"
    PHP_ASC_URL = "https://www.php.net/distributions/php-${PHP_VERSION}.tar.xz.asc"
    PHP_SHA256  = PHP_SHA256
  }
  tags = flatten([
    for image in REGISTRY_IMAGES : [
      for s in item.suffixes : [
        tag(image, PHP_VERSION, s),
        tag(image, minor(PHP_VERSION), s),
      ]
    ]
  ])
  attest = ["type=provenance,disabled=true"]
}
