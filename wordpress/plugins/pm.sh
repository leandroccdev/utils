#!/bin/bash

G_FN_RESULT="__fn_result"

base_url="https://wordpress.org"
plugins_url="${base_url}/plugins"
plugins_dir="plugins"
plugins_sitemap_index="${plugins_url}/sitemap-index-1.xml"
plugin_meta_file="meta.json"
max_workers=10
min_installations=1000
parallel_log="download.log"
join_files_log="join.log"
excluded_js_libs_file="excluded_js_libs.txt"
plugin_sources_file="sources.zip"
plugin_sources_dir="sources"

#region die
# Prints an error message to stderr and terminates the script.
#
# Parameters:
# $1: Error message to display.
#
# Side effects:
# - Writes message to stderr.
# - Terminates script execution (exit 1).
#
# Returns:
# Does not return (exits with status 1).
#
# Output:
# Prints the error message to stderr.
#endregion
function die {
  echo -e "$1" >&2
  exit 1
}

#region err
# Prints an error message to standard error output and returns failure.
#
# Parameters:
# $1: Error message to display.
#
# Side effects:
# - Writes message to stderr.
#
# Returns:
# 1 always.
#
# Output:
# Prints the provided error message to stderr.
#endregion
function err {
  echo -e "$1" >&2
  return 1
}

#region msg
# Prints a message to standard error output.
#
# Parameters:
# $1: Message to display.
#
# Side effects:
# - Writes output to stderr.
#
# Returns:
# 0 always.
#
# Output:
#endregion Prints the provided message to stderr.
function msg {
  echo -e "$1" >&2
}

#region check_cmd
# Checks whether a given command exists in PATH using command -v.
# Parameters:
# - cmd: string. Name of the command to verify in the system PATH.
# Side effects:
# - Calls die() with an error message if the command is not found
# (may terminate the script depending on die implementation).
# Returns:
# - 0 if the command exists.
# - 1 if the command is not found.
# Output:
# - No output on success.
# - On failure, error handling is delegated to die().
#endregion
function check_cmd {
  local cmd="$1"
  if ! command -v "$cmd" > /dev/null 2>&1; then
    die "[Error] '$cmd' not installed!"
    return 1
  fi
  return 0
}

#region user_select_plugin_version
#
# Selects a plugin version directory from the given plugin path.
# If multiple versions exist, prompts the user to choose via gum.
# Defaults to the first version when only one is available. Optionally
# validates the plugin directory before listing its contents. Stores
# the selected version path in the variable referenced by $G_FN_RESULT.
#
# Args:
#   $1  Plugin directory containing version subdirectories
#
# Output:
#   None (result assigned to variable via $G_FN_RESULT)
#
# Side effects:
#   Calls check_plugin_dir when plugin_dir is provided
#   Prompts user interaction via gum if multiple versions exist
#   Writes result into variable referenced by $G_FN_RESULT
#endregion
function user_select_plugin_version {
  local plugin_dir="$1" # Empty when is not set

  if [[ -n "$plugin_dir"  ]]; then
    check_plugin_dir "$plugin_dir"
  fi

  local plugin_versions
  mapfile -t plugin_versions < <(ls -A -- "$plugin_dir")

  local selected_version="${plugin_versions[0]}"
  if [[ ${#plugin_versions[@]} -gt 1 ]]; then
    selected_version=$(gum choose "${plugin_versions[@]}")
  fi
  printf -v "$G_FN_RESULT" '%s' "${plugin_dir}/${selected_version}"
}

#region check_plugin_dir
# Validates that a plugin directory argument is provided and exists.
#
# Side effects:
# - May terminate script execution if parameter is missing (exit 1).
# - Reads filesystem to verify directory existence.
#
# Returns:
# 1 if the directory does not exist.
# Does not return if parameter is missing (exits with status 1).
# Implicitly succeeds if validation passes.
#
# Parameters:
# $1: Path to the plugin directory.
#endregion
function check_plugin_dir {
  if [[ -z "$1" ]]; then
    die "[Error] Missing ${FUNCNAME[0]}: parameter!"
  fi

  local plugin_dir="$1"
  if [[ ! -d $plugin_dir ]]; then
    die "[Error] Plugin not found!"
  fi
}

#region check_plugin_zip_file
# Validates that a plugin zip file argument is provided and exists.
#
# Side effects:
# - Terminates the script execution on failure (exit 1).
# - Reads filesystem to verify file existence.
#
# Returns:
# Does not return on failure (exits with status 1).
# Implicitly succeeds if validation passes.
#
# Parameters:
# $1: Path to the plugin zip file.
#endregion
function check_plugin_zip_file {
  if [[ -z "$1" ]]; then
    die "[Error] Missing ${FUNCNAME[0]}: parameter!"
  fi

  local plugin_zip_file="$1"
  if [[ ! -f "$plugin_zip_file" ]]; then
    die "[Error] File '${plugin_zip_file}' is missing!"
  fi
}

#region check_plugin_meta_file
# Validates that a plugin metadata file exists within a given directory.
# Constructs the expected meta file path and ensures it is present.
#
# Parameters:
# $1: Path to the plugin directory containing the meta file.
#
# Side effects:
# - Reads filesystem to verify file existence.
# - Terminates script execution on failure via die (exit 1).
#
# Returns:
# Does not return on failure (exits with status 1).
# Implicitly succeeds if validation passes.
#
# Output:
# No output on success. Prints error message to stderr on failure.
#endregion
function check_plugin_meta_file {
  if [[ -z "$1" ]]; then
    die "[Error] Missing ${FUNCNAME[0]}: parameter!"
  fi

  local plugin_meta_file="${1}/${plugin_meta_file}"
  if [[ ! -f $plugin_meta_file ]]; then
    die "[Error] Meta file '$plugin_meta_file' is missing!"
  fi
}

#region get_plugin_download_url_from_meta_file
# Extracts the download URL from a plugin metadata file.
# Validates the metadata file and parses its JSON content using jq.
# Stores the result in a variable referenced by G_FN_RESULT.
#
# Parameters:
# $1: Path to the plugin version directory containing the meta file.
#
# Side effects:
# - Reads filesystem to access the metadata file.
# - Invokes jq to parse JSON content.
# - Writes the extracted value into a variable via printf -v.
# - May terminate script execution if validation fails.
#
# Returns:
# 0 on success.
# Non-zero if jq fails or validation fails.
#
# Output:
# No stdout output. Sets the variable referenced by G_FN_RESULT with the
# extracted download URL.
#endregion
function get_plugin_download_url_from_meta_file {
  local plugin_version_dir="$1"
  check_plugin_meta_file "$plugin_version_dir"
  local plugin_meta_file="${plugin_version_dir}/${plugin_meta_file}"
  printf -v "$G_FN_RESULT" '%s' $(jq -r '.download' "$plugin_meta_file")
}

#region get_plugin_zip_file_from_meta_file
# Derives the plugin zip file name from the download URL in the metadata.
# Uses get_plugin_download_url_from_meta_file to retrieve the URL and
# extracts the basename of that URL.
#
# Parameters:
# $1: Path to the plugin version directory containing the meta file.
#
# Side effects:
# - Reads filesystem indirectly via metadata helper function.
# - Invokes external commands (basename).
# - Writes the result into a variable via print -v.
#
# Returns:
# 0 on success.
# Non-zero if upstream function or commands fail.
#
# Output:
# No stdout output. Sets the variable referenced by G_FN_RESULT with the
# derived plugin zip file name.
#endregion
function get_plugin_zip_file_from_meta_file {
  local plugin_version_dir="$1"
  get_plugin_download_url_from_meta_file "$plugin_version_dir"
  printf -v "$G_FN_RESULT" '%s' $(basename "$__fn_result")
}

#region get_plugin_version_zip_file
#
# Resolves the path to a plugin ZIP file for a selected version.
# Invokes user_select_plugin_version to determine the version
# directory, then constructs the ZIP file path using the plugin
# directory name. Stores the result in the variable referenced by
# $G_FN_RESULT.
#
# Args:
#   $1  Plugin base directory
#
# Output:
#   None (result assigned to variable via $G_FN_RESULT)
#
# Side effects:
#   Calls user_select_plugin_version
#   Writes result into variable referenced by $G_FN_RESULT
#endregion
function get_plugin_version_zip_file {
  local plugin_dir="$1"
  user_select_plugin_version "$plugin_dir"
  local plugin_version_dir="$__fn_result"
  get_plugin_zip_file_from_meta_file "$plugin_version_dir"
  local plugin_zip_file="$__fn_result"
  plugin_zip_file="${plugin_version_dir}/${plugin_zip_file}"
  printf -v "$G_FN_RESULT" '%s' "$plugin_zip_file"
}

#region query_plugins_sitemap_index
# Queries the WordPress plugins sitemap index and extracts sitemap URLs.
#
# Fetches the sitemap index from the configured global variable and parses
# all referenced XML sitemap URLs from the response.
#
# Parameters:
#
# Side effects:
# - Performs HTTP request via curl.
# - Reads global variable plugins_sitemap_index.
# - Parses HTML/XML-like content using grep and tr.
# - Writes result into variable referenced by G_FN_RESULT.
#
# Returns:
# 0 on success.
# 1 if the HTTP request fails or status code is not 200.
#
# Output:
# No stdout output. Sets G_FN_RESULT with extracted sitemap URLs.
#endregion
function query_plugins_sitemap_index {
  if [[ -z "$plugins_sitemap_index" ]]; then
    die "[Error] Internal variable 'plugins_sitemap_index' not set!"
  fi

  local data=$(curl -s -w "code:%{http_code}" "${plugins_sitemap_index}")
  local status_code=$(echo -n $data | grep -Eo 'code:[0-9]{3}' | cut -d: -f2)
  if [[ $status_code != "200" ]]; then
    err "[Error] Unable to query '${plugins_sitemap_index}'!" || return 1
  fi

  local xpath='//*[local-name()="sitemap"]/*[local-name()="loc"]/text()'
  local sitemaps=$(
    echo -n "$data" \
      | head -n -1 \
      | xmllint --xpath "$xpath" - \
      | sort -V \
      | tr '\n' ' '
    )
  unset xpath
  printf -v "$G_FN_RESULT" '%s' "$sitemaps"
}

#region query_plugin_sitemap
# Queries a plugin sitemap URL and extracts plugin page URLs.
#
# Fetches the sitemap XML and parses all <loc> entries to obtain plugin
# URLs in a normalized, sorted form, filtering only valid plugin slugs.
#
# Parameters:
# $1: Sitemap URL to query.
#
# Side effects:
# - Performs HTTP request via curl.
# - Parses XML using xmllint.
# - Sorts and filters extracted URLs using grep.
# - Writes result into variable referenced by G_FN_RESULT.
#
# Returns:
# 0 on success.
# 1 if the URL is empty or the HTTP request fails.
#
# Output:
# No stdout output. Sets G_FN_RESULT with filtered plugin URLs.
#endregion
function query_plugin_sitemap {
  local sitemap_url="$1"

  if [[ -z "$sitemap_url" ]]; then
    err "[Error] ${FUNCNAME[0]}: Empty URL argument!" || return 1
  fi

  local data=$(curl -s -w "code:%{http_code}" "$sitemap_url")
  local status_code=$(echo -n $data | grep -Eo 'code:[0-9]{3}' | cut -d: -f2)
  if [[ $status_code != "200" ]]; then
    err "[Error] Unable to get '${sitemap_url}'!" || return 1
  fi

  local xpath='//*[local-name()="url"]/*[local-name()="loc"]/text()'
  # Grep line deletes all URLs wich do not contain a plugin slug
  local plugins_url=$(
    echo -n "$data" \
      | head -n -1 \
      | xmllint --xpath "$xpath" - \
      | sort -V \
      | grep -E '/plugins/[^/]+/?$' - \
    )
  printf -v "$G_FN_RESULT" '%s' "$plugins_url"
}

#region prepare_php_files_to_join
#
# Reads multiple PHP files and outputs their contents wrapped with START/END
# markers.
# Expects one or more file paths as arguments.
# Exits with error if no arguments are provided or if any file does not exist.
# Logs missing-argument errors to $join_files_log.
#
# Args:
#   $@  File paths to process
#
# Output:
#   Formatted file contents to stdout
#
# Side effects:
#   Writes to $join_files_log on missing args
#   Exits on error conditions
#endregion
function prepare_php_files_to_join {
  if [[ $# -eq 0 ]]; then
    echo "[Error] ${FUNCNAME[0]}: missing arguments!" >> $join_files_log
    exit 1
  fi

  for path in "$@"; do
    # path not found
    [[ ! -f "$path" ]] && exit 1

    printf "START FILE: %s\n\n" "$path"
    cat -- "$path"
    printf "\n\nEND FILE: %s\n\n" "$path"
  done
}

#region prepare_js_files_to_join
#
# Reads multiple JavaScript files and outputs their contents wrapped
# with START/END markers. Skips files matching entries in the
# excluded_js_libs array. Exits if no arguments are provided or if a
# file path does not exist. Logs excluded libraries to $join_files_log.
#
# Args:
#   $@  File paths to process
#
# Output:
#   Formatted file contents to stdout
#
# Side effects:
#   Writes excluded file logs to $join_files_log
#   Exits on missing arguments or invalid file paths
#endregion
function prepare_js_files_to_join {
  if [[ $# -eq 0 ]]; then
    echo "[Error] ${FUNCNAME[0]}: missing arguments!" >> $join_files_log
    exit 1
  fi

  for path in "$@"; do
    # path not found
    [[ ! -f "$path" ]] && exit 1

    # Skip exluded files
    for lib in "${excluded_js_libs[@]}"; do
      if [[ "$lib" == *"$path"* ]]; then
        echo "Excluded lib: $path" >> $join_files_log
        continue
      fi
    done

    printf "START FILE: %s\n" "$path"
    cat -- "$path"
    printf "\nEND FILE: %s\n" "$path"
  done
}

#region join_plugin_files
# Aggregates plugin source files (PHP and JS) into consolidated text files
# and packages them into a compressed archive.
# Operates within the specified plugin version directory and excludes
# dependency directories such as vendor and node_modules.
#
# Parameters:
# $1: Path to the plugin version directory.
#
# Side effects:
# - Changes working directory using pushd/popd.
# - Reads and traverses filesystem recursively.
# - Creates a temporary sources directory if not present.
# - Generates intermediate joined source files for PHP and JS.
# - May prompt user for overwrite confirmation via gum.
# - Removes existing output file if overwrite is confirmed.
# - Compresses generated files into a zip archive.
#
# Returns:
# 0 on success.
# 1 if argument is missing or user declines overwrite.
# Non-zero if any underlying command fails.
#
# Output:
# No direct stdout output. Produces a zip archive containing joined
# source files within the plugin version directory.
#endregion
function join_plugin_files {
  if [[ -z "$1" ]]; then
    err "[Error] ${FUNCNAME[0]}: Missing argument!" || return 1
  fi

  local plugin_version_dir="$1"
  local _plugin_sources_file="${plugin_version_dir}/${plugin_sources_file}"

  pushd $plugin_version_dir > /dev/null
  if [[ -f "$plugin_sources_file" ]]; then
    if gum confirm --default=false \
        "'${_plugin_sources_file}' already exists. Overwrite it?"; then
      rm "$plugin_sources_file"
    else
    popd > /dev/null
      return 1
    fi
  fi

  # Create sources dir
  if [[ ! -d "$plugin_sources_dir" ]]; then
    mkdir "$plugin_sources_dir"
  fi

  local source_file_name=$(echo "$EPOCHSECONDS" | md5sum | awk '{ print $1 }')
  joined_php_source_file="${plugin_sources_dir#.}/${source_file_name}_php.txt"
  joined_js_source_files="${plugin_sources_dir#.}/${source_file_name}_js.txt"

  # Join PHP source files
  find . \
    -type d -name 'vendor' -prune -o \
    -type f -name "*.php" ! -empty \
    -exec bash -c 'prepare_php_files_to_join "$@"' _ {} + \
    > "$joined_php_source_file"

  # Join JS source files
  find . \
    -type d -name 'node_modules' -prune -o \
    -type f -name "*.js" ! -empty \
    -exec bash -c 'prepare_js_files_to_join "$@"' _ {} + \
    > $joined_js_source_files

  # Delete all compressed files?
  local zip_dash_m
  if gum confirm --default=false \
      "Delete sources files after compressed them!"; then
    zip_dash_m="-m"
  else
    zip_dash_m=""
  fi

  # Some plugins doesn't have any js files
  if [[ -s "${joined_js_source_files}" ]]; then
    zip -9 -r $zip_dash_m "$plugin_sources_file" \
      "${plugin_sources_dir}" \
      > /dev/null
  else
    zip -9 -r $zip_dash_m "$plugin_sources_file" \
      "${plugin_sources_dir}" \
      > /dev/null
  fi

  popd > /dev/null
}

#region download_plugin
# Downloads the latest available version of a WordPress plugin.
#
# Fetches plugin data from the provided URL, parses metadata such as
# version, download URL, active installations, and compatibility
# information, and stores the plugin version in the local filesystem.
#
# The function also validates installation thresholds and skips plugins
# that are closed or do not meet minimum installation requirements.
#
# Parameters:
# $1: Plugin URL pointing to the WordPress plugin page.
#
# Side effects:
# - Performs HTTP requests via curl.
# - Parses HTML and JSON using xmllint and jq.
# - Writes plugin metadata to disk (plugin_meta_file).
# - Creates plugin version directories under plugins_dir.
# - Downloads plugin zip file via wget.
# - Writes processing timestamp to processed_at.txt.
# - May change working directory using pushd/popd.
# - Prints messages and errors to stdout/stderr.
#
# Returns:
# 0 on successful download and extraction of plugin metadata.
# 1 if validation fails, download fails, or plugin is skipped.
#
# Output:
# Logs status messages and errors to stdout/stderr.
#endregion
function download_plugin {
  local plugin_url="$1";

  if [[ -z "${plugin_url}" ]]; then
    err "[Error] ${FUNCNAME[0]}: Empty URL argument!" || return 1
  fi

  local data=$(curl -s -w "code:%{http_code}" "$plugin_url")
  local status_code=$(echo -n $data | grep -Eo 'code:[0-9]{3}' | cut -d: -f2)
  if [[ $status_code != "200" ]]; then
    err "[Error] Unable to get: '$plugin_url'\nHTTP CODE: $status_code" \
      || return 1
  fi

  local plugin_slug="${plugin_url%/}"
  plugin_slug="${plugin_slug##*/}"

  # Extracts active installations
  local xpath='normalize-space(//li[contains(.,"Active installations")]/strong)'
  local plugin_active_installations=$(echo -n "$data" |
    xmllint --html --xpath "$xpath" - 2>/dev/null)
  unset xpath

  # Closed plugin
  if [[ "N/A" == *"${plugin_active_installations}"* ]]; then
    err "[Skip:${plugin_slug}] Plugin is closed!" || return 1
  fi

  # Avoid download of plugins with less than 100 installations
  local installations=$(echo -n "${plugin_active_installations:-0}" |
    grep -Eo '[0-9,]+' | tr -d ' ,')

  if [[ -z "$installations" ]]; then
    err "[Error] Unable to extract plugin installations!" || return 1
  fi

  # Disabled when min_installations is zero
  if (( min_installations > 0 )); then
    local _min_installations

    (( installations = 10#${installations:-0} ))
    (( _min_installations = 10#${min_installations:-0} ))

    if (( installations < _min_installations )); then
      err "[Skip:${plugin_slug}] It has fewer than $installations installs!" \
        || return 1
    fi
  fi

  xpath='string(//script[@type="application/ld+json"])'
  local plugin_meta=$(echo -n "$data" |
    xmllint --html --xpath "$xpath" - 2>/dev/null |
    sed 's/^<!\[CDATA\[//; s/\]\]>$//')
  unset xpath

  # Extracts meta fields
  xpath='normalize-space(//li[contains(.,"WordPress version")]/strong)'
  plugin_min_wp_version=$(echo -n "$data" |
    xmllint --html --xpath "$xpath" - 2>/dev/null)
  unset xpath

  xpath='normalize-space(//li[contains(.,"Tested up to")]/strong)'
  plugin_tested_up_to=$(echo -n "$data" |
    xmllint --html --xpath "$xpath" - 2>/dev/null)
  unset xpath

  local plugin_name=$(echo -n "$plugin_meta" | jq -r '.[0].name')
  local plugin_description=$(echo -n "$plugin_meta" | jq -r '.[0].description')
  local plugin_version=$(echo -n "$plugin_meta" | jq -r '.[0].softwareVersion')
  local plugin_download_url=$(echo -n "$plugin_meta" | jq -r '.[0].downloadUrl')

  # Write data to specific version folder
  local plugin_version_dir="${plugins_dir}/${plugin_slug}/${plugin_version}/"

  if [[ -d "$plugin_version_dir" ]]; then
    err "[Skip:${plugin_slug}] Version $plugin_version already downloaded!" \
      || return 1
  else
    mkdir -p "$plugin_version_dir" || return 1
    pushd "$plugin_version_dir" > /dev/null

    echo -n "$(date "+%Y-%m-%d %H:%M:%S")" > "processed_at.txt"

    # Writes meta data
    cat > "$plugin_meta_file" <<EOF
{
  "plugin": "$plugin_name",
  "slug": "$plugin_slug",
  "description": "$plugin_description",
  "version": "$plugin_version",
  "wp_min_version": "$plugin_min_wp_version",
  "active installations": "$plugin_active_installations",
  "tested_up_to": "$plugin_tested_up_to",
  "url": "$plugin_url",
  "download": "$plugin_download_url"
}
EOF
    local download_file_name=$(basename "${plugin_download_url}")
    wget -q "$plugin_download_url" -O "${download_file_name}" || return 1

    if [[ ! -f "$download_file_name" ]]; then
      msg "[Error] File '$plugin_download_url' not downloaded!"
    fi

    popd > /dev/null

    msg "[$plugin_slug] Version $plugin_version Downloaded!"
  fi

  return 0
}

#region query_plugins_sitemap
# Orchestrates the full plugin discovery and download workflow.
# Steps:
# 1. Retrieves the sitemap index from WordPress plugins site.
# 2. Iterates over each sitemap URL.
# 3. Extracts plugin URLs from each sitemap.
# 4. Executes downloads in parallel using GNU parallel.
# 5. Skips sitemaps that fail to be retrieved.
#
# Side effects:
# - Triggers concurrent plugin downloads.
# - Writes download logs to the configured joblog file.
# - Uses exported function `download_plugin` for parallel execution.
#
# Returns:
# 0 on completion (even if some sitemaps fail, they are skipped)
# non-zero only if upstream commands fail critically.
#endregion
function query_plugins_sitemap {
  query_plugins_sitemap_index
  local sitemap_index="$__fn_result"

  # Download every sitemap
  for sitemap_url in $sitemap_index; do
    query_plugin_sitemap "$sitemap_url"
    local sitemaps="$__fn_result"

    # Some error happens
    [[ $? -ne 0 ]] && continue

    msg "Processing sitemap: '$sitemap_url'..."

    # Download plugins in parallel
    local urls
    mapfile -t urls <<< "$sitemaps"
    msg "Downloading plugins..."

    parallel -j "${max_workers}" --joblog "$parallel_log" \
      download_plugin ::: "${urls[@]}"

    msg "All downloads finished!"
  done
}

#region unzip_plugin
# Extracts a plugin zip file for a selected plugin version.
# Resolves the zip file path via get_plugin_version_zip_file and
# conditionally overwrites existing extracted content.
#
# Parameters:
# $1: Plugin name (relative to global plugins_dir).
#
# Side effects:
# - Reads filesystem structure of plugin directories and versions.
# - May invoke an interactive UI via gum for confirmation.
# - Removes existing extraction directory if user confirms overwrite.
# - Extracts plugin archive contents into the version directory.
#
# Returns:
# 0 on success.
# Non-zero if unzip fails or validation fails.
#
# Output:
# No direct output. Relies on __fn_result for intermediate values.
#endregion
function unzip_plugin {
  local plugin_dir="${plugins_dir}/$1"
  local plugin_slug="$1"
  get_plugin_version_zip_file "$plugin_dir"
  local plugin_version_dir=$(dirname "$__fn_result")
  local plugin_zip_file="$__fn_result"
  check_plugin_zip_file "$plugin_zip_file"
  local plugin_zip_out_dir="${plugin_version_dir}/${plugin_slug}"

  if [[ ! -d "$plugin_zip_out_dir" ]]; then
    unzip -q -d "$plugin_version_dir" "$plugin_zip_file"
  # Out dir already exists
  else
    if gum confirm --default=false \
      "'${plugin_zip_out_dir}' already exists. Overwrite it?"; then
      rm -rf "$plugin_zip_out_dir"
      unzip -q -d "$plugin_version_dir" "$plugin_zip_file"
    fi
  fi
}

#region create_plugin_source_files
# Orchestrates plugin extraction and source aggregation workflow.
# Unzips a plugin, generates consolidated source files, and optionally
# removes the extracted output directory.
#
# Parameters:
# $1: Plugin slug (directory name under global plugins_dir).
#
# Side effects:
# - Extracts plugin archive via unzip_plugin.
# - Reads and writes filesystem content during source aggregation.
# - Invokes interactive prompts via gum for confirmations.
# - Deletes extracted plugin directory if user confirms.
#
# Returns:
# 0 on success.
# Non-zero if any underlying operation fails.
#
# Output:
# No direct stdout output. Relies on helper functions for intermediate
# state via __fn_result.
#endregion
function create_plugin_source_files {
  local plugin_slug="$1"
  local plugin_dir="${plugins_dir}/${plugin_slug}"
  unzip_plugin "$plugin_slug"
  local plugin_version_dir=$(dirname "$__fn_result")

  join_plugin_files "$plugin_version_dir"
  
  local plugin_zip_out_dir="${plugin_version_dir}/${plugin_slug}"
  if gum confirm --default=false \
    "Delete '${plugin_zip_out_dir}' directory?"; then
    rm -rf "$plugin_zip_out_dir"
  fi
}

#region print_help
# Prints the CLI help menu for the plugins tool.
#
# Parameters:
#
# Side effects:
# - Writes help text to stdout.
#
# Returns:
# 0 always.
#
# Output:
# Displays available commands and their descriptions for the plugins tool.
#endregion
function print_help {
  cat <<'EOF'
Plugins tool

  -csf|--create-sources-files  Create unified source files for a plugin.

  -dp|--download-plugin        Download a single plugin from WordPress.org.

  -dps|--download-plugins      Download plugins listed in the WordPress.org sitemap.xml.
                               Supports optional parameters:
                               max_workers, min_installations

  -uzp|--unzip-plugin          Extract a plugin ZIP file for a selected version.

  -h|--help                    Show this help message.
EOF
}

#region Check dependencies
deps=(
  curl
  jq
  xmllint
  wget
  zip
  unzip
  find
  parallel
  gum
  md5sum
  grep
  cut
  sort
  tr
  head
  ls
  basename
  dirname
  cat
  printf
  rm
  mkdir
)
for dep in "${deps[@]}"; do
  check_cmd "$dep"
done
unset deps
#endregion

#region Read and export excluded js libs
if [[ ! -f "${excluded_js_libs_file}" ]]; then
  echo "[Error] File '${excluded_js_libs_file}' not found!"
  exit 1
fi

mapfile -t excluded_js_libs < "${excluded_js_libs_file}"
#endregion

#region Exported vars/functions
export excluded_js_libs
export join_files_log
export min_installations
export plugins_dir
export plugin_meta_file
export -f die
export -f err
export -f msg
export -f join_plugin_files
export -f prepare_php_files_to_join
export -f prepare_js_files_to_join
export -f download_plugin
#endregion

#region Arguments parsing
while [[ $# -gt 0 ]]; do
  case "$1" in
    -csf|--create-sources-files)
      # Plugin name not given
      if [[ -z "$2" ]]; then
        die "[Error] Plugin name not provided!"
      fi
      create_plugin_source_files "$2"
      exit $?
      ;;

    -dp|--download-plugin)
      if [[ -z "$2" ]]; then
        die "[Error] PLugin name not provided!"
      fi
      # Allows you to download any plugin manually
      min_installations=0
      download_plugin "${plugins_url}/${2}/"
      exit $?
      ;;

    -dps|--download-plugins)
      shift
      if [[ -n "$1" ]]; then
        max_workers="$1"
      fi
      if [[ -n "$2" ]]; then
        min_installations="$2"
      fi

      echo "Max workers set to: $max_workers"
      echo "Min installations set to: $min_installations"
      query_plugins_sitemap
      exit $?
      ;;

    -uzp|--unzip-plugin)
      # Plugin name not given
      if [[ -z "$2" ]]; then
        die "[Error] Plugin name not provided!"
      fi
      unzip_plugin "$2"
      exit $?
      ;;

    -h|--help|*)
      print_help
      shift
      ;;
  esac
done
#endregion
