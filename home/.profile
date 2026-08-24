# ~/.profile — login shell environment (mise-managed via dotfiles repo)
# GUI sessions additionally get the same variables from
# ~/.config/environment.d/10-mise.conf (keep both in sync).

# PATH
case ":${PATH}:" in
  *:"$HOME/.local/bin":*) ;;
  *) PATH="$HOME/.local/bin:$PATH" ;;
esac
case ":${PATH}:" in
  *:"$HOME/.local/share/npm/bin":*) ;;
  *) PATH="$HOME/.local/share/npm/bin:$PATH" ;;
esac
export PATH

# Terminfo
export TERMINFO_DIRS="/etc/terminfo:/usr/share/terminfo:/lib/terminfo"

# Cursor
export XCURSOR_THEME="Bibata-Modern-Ice"
export XCURSOR_SIZE="24"
export XCURSOR_PATH="$HOME/.local/share/icons:$HOME/.icons:/usr/share/icons"

# GUI / Wayland
export GDK_BACKEND="wayland,x11,*"
export BROWSER="chrome"
export WLR_RENDERER="vulkan"
export XDG_SESSION_TYPE="wayland"
export SWAY_UNSUPPORTED_GPU="1"
export CLUTTER_BACKEND="wayland"

# Qt
export QT_QPA_PLATFORM="wayland"
export QT_QPA_PLATFORMTHEME="gtk3"
export QT_IM_MODULES="wayland;fcitx"

# SDL
export SDL_VIDEODRIVER="wayland,x11"
export SDL_IM_MODULE="fcitx"

# Mozilla
export MOZ_ENABLE_WAYLAND="1"

# Fcitx5
export XMODIFIERS="@im=fcitx"
export INPUT_METHOD="fcitx"

# Misc
export EDITOR="hx"
