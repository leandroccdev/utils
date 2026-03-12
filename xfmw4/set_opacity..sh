# ----------------------------------------------------
# XFWM4: Set inactive window opacity
# ----------------------------------------------------
# $1: New opacity value (0-100%).
# - r: Reset opacity
# - [n]: increase/decrease opacity by [n]
# ----------------------------------------------------
# For .bashrc (keyboard shortcuts)
# ----------------------------------------------------
# Description: Decrease opacity
# Shortcut: CTRL+ALT+-
# Command: bash -ic "xfwm4_g_inactive_opacity_set -1"
# ----------------------------------------------------
# Description: Increase opacity
# Shorcut: CTRL+ALT++
# Command: bash -ic "xfwm4_g_inactive_opacity_set 1"
# ----------------------------------------------------
# Description: Reset opacity
# Shorcut: CTRL+ALT+R
# Command: bash -ic "xfwm4_g_inactive_opacity_set r"
# ----------------------------------------------------
function xfwm4_g_inactive_opacity_set {
    notify_title="XFWM4: Window Inactive Opacity"
    # Reset opacity
    if [[ $1 == "r" ]]; then
        xfconf-query -c xfwm4 -p /general/inactive_opacity -s 100
        notify-send "$notify_title" "Opacity reset!"
        return
    fi

    # Modify opacity
    opacity=$(xfconf-query -c xfwm4 -p /general/inactive_opacity)
    local value=$1
    ((opacity = opacity + value))

    if [[ $opacity -ge 0 && $opacity -le 100 ]]; then
        xfconf-query -c xfwm4 -p /general/inactive_opacity -s $opacity
        notify-send "$notify_title" "Set to: ${opacity}%"
    fi
}
