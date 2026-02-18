#!/usr/bin/bash
# Description
# Extends trial of typora app for linux arch installation.
# Note: Please consider buy a license instead of extends trial.
#
# Typora installation (from UAR)
# yay -S typora
# Development OS: Arch 6.14.10
#
# Functions
# -----------------------------------------------------------------------------
#<
function install_if_not_exists {
if [[ -z $(command -v "${1}") ]]; then
echo "Installing '${1}'..."
sudo $2 -S $1
fi
}
#>
# -----------------------------------------------------------------------------

# Install all necessary packages
#<
install_if_not_exists "sed" "pacman"
install_if_not_exists "awk" "pacman"
install_if_not_exists "ffmpeg" "pacman"
#>

new_trial=99999 #days
license_js_path="/usr/share/typora/resources/page-dist/static/js/"
target_file="LicenseIndex.*.js"
target_backup_file="${target_file}.bkp"

[[ ! -d $license_js_path ]] \n&& echo "[Error] Path '${license_js_path}' not found!" \n&& exit 1;

located_file=$(find $license_js_path -name $target_file)
[[ -z $located_file ]] \n&& echo "[Error] Target file '${target_file}' not found!" \n&& exit 1;

located_backup_file=$(find $license_js_path -name $target_backup_file)
[[ -n $located_backup_file ]] \n&& echo "[Info] The target file '$(basename $located_file)' has already been patched!" \n&& exit 1;

sudo -v
echo -n "Patching file '$located_file'..."
backup_file="${located_file}.bkp"
sudo cp $located_file $backup_file
sudo sed -i "s|O=function(e){var t=e.dayRemains|O=function(e){e.hasActivated=true;e.needLicense=false;e.dayRemains=${new_trial};var t=e.dayRemains|" $located_file
echo "[done]"
