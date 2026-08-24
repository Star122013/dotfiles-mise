$env.config.buffer_editor = "hx"
$env.config.show_banner = false

$env.LANG = "en_US.UTF-8"

load-env {
  PATH: (
    $env.PATH
    | append "/usr/local/bin"
    | append "/usr/bin"
    | append "/bin"
    | append "/home/linuxbrew/.linuxbrew/bin/"
    | append "/var/home/qwerhyy/.zvm/bin"
    | append "/var/home/qwerhyy/.pixi/bin"
    | str join ":"
  )
  EDITOR: "hx"
  HOME: "/var/home/qwerhyy"
  XDG_CACHE_HOME: "/var/home/qwerhyy/.cache"
  TERMINFO_DIRS: $"($env.HOME)/.nix-profile/share/terminfo"
}
