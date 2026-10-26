variable "REGISTRY_IMAGES" {
  type    = list(string)
  default = ["ghcr.io/classi/ruby"]
}

variable "RUBY_VERSION" {
  validation {
    condition     = can(regex("^(3\\.3|3\\.4|4\\.0)\\.[0-9]+$", RUBY_VERSION))
    error_message = "RUBY_VERSION must be 3.3.x, 3.4.x or 4.0.x"
  }
}

variable "RUBY_DOWNLOAD_SHA256" {
  validation {
    condition     = can(regex("^[0-9a-f]{64}$", RUBY_DOWNLOAD_SHA256))
    error_message = "RUBY_DOWNLOAD_SHA256 must be 64 lowercase hex characters"
  }
}

function "minor" {
  params = [version]
  result = regex("^([0-9]+\\.[0-9]+)\\.", version)[0]
}

group "default" {
  targets = ["ruby"]
}

target "ruby" {
  name = "ruby-${item.variant}"
  matrix = {
    item = [
      { variant = "slim-trixie", suffixes = ["slim-trixie", "slim"] },
      { variant = "slim-bookworm", suffixes = ["slim-bookworm"] },
    ]
  }
  context = "ruby/${minor(RUBY_VERSION)}/${item.variant}"
  args = {
    RUBY_VERSION         = RUBY_VERSION
    RUBY_DOWNLOAD_URL    = "https://cache.ruby-lang.org/pub/ruby/${minor(RUBY_VERSION)}/ruby-${RUBY_VERSION}.tar.xz"
    RUBY_DOWNLOAD_SHA256 = RUBY_DOWNLOAD_SHA256
  }
  tags = flatten([
    for image in REGISTRY_IMAGES : [
      for s in item.suffixes : [
        "${image}:${RUBY_VERSION}-${s}",
        "${image}:${minor(RUBY_VERSION)}-${s}",
      ]
    ]
  ])
  attest = ["type=provenance,disabled=true"]
}
