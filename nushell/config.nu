# config.nu
#

$env.LANG = "en_US.UTF-8"

# Installed by:
# version = "0.111.0"
#
# This file is used to override default Nushell settings, define
# (or import) custom commands, or run any other startup tasks.
# See https://www.nushell.sh/book/configuration.html
#
# Nushell sets "sensible defaults" for most configuration settings, 
# so your `config.nu` only needs to override these defaults if desired.
#
# You can open this file in your default editor using:
#     config nu
#
# You can also pretty-print and page through the documentation for configuration
# options using:
#     config nu --doc | nu-highlight | less -R


def bh [...args: string] {
  if ($args | is-empty) {
    printf "usage: bh <command>"
    return
  }

  let command = ($args | first 1)
  let subcommand = ($args | skip 1)

  run-external $command ...$subcommand "--help" o+e>| bat -pl help
}

# fix xterm-ghostty error: preserve TERMINFO_DIRS across sudo
$env.TERMINFO_DIRS = $"($env.HOME)/.nix-profile/share/terminfo"
def --wrapped sudo [...args] {
  if ($env.TERMINFO_DIRS? | is-not-empty) {
    ^sudo --preserve-env=TERMINFO_DIRS ...$args
  } else {
    ^sudo ...$args
  }
}

mkdir ($nu.data-dir | path join "vendor/autoload")
zoxide init nushell --cmd cd | save -f ($nu.data-dir | path join "vendor/autoload/zoxide.nu")

use std/config *

# Initialize the PWD hook as an empty list if it doesn't exist
$env.config.hooks.env_change.PWD = $env.config.hooks.env_change.PWD? | default []

$env.config.hooks.env_change.PWD ++= [{||
  if (which direnv | is-empty) {
    # If direnv isn't installed, do nothing
    return
  }

  direnv export json | from json | default {} | load-env
  # If direnv changes the PATH, it will become a string and we need to re-convert it to a list
  $env.PATH = do (env-conversions).path.from_string $env.PATH
}]
