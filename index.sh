#!/bin/bash

# ========================================
# Filesystem Navigator Module
# ========================================
# Interactive filesystem navigation for path and file selection
# Usage: source libs/navigator/index.sh

# Get the directory where this script is located
NAVIGATOR_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Import navigator modules
source "$NAVIGATOR_DIR/render.sh"
source "$NAVIGATOR_DIR/input.sh"

# Global variables for navigation state
CURRENT_SELECTION=1
PREVIOUS_SELECTION=1
NAV_LIST_START_LINE=9  # Line where directory list starts (after header + location + page info)
declare -g -a NAV_DIRECTORIES=()
declare -g -a NAV_DISPLAY_NAMES=()
declare -g -a NAV_ITEM_TYPES=()      # "dir" or "file" for each item
declare -g -a MARKED_FILES=()        # Absolute paths of marked files
declare -g BROWSER_MODE="directory"  # "directory" or "files"
declare -g NAV_PAGE=1                # Current page (1-indexed)
declare -g NAV_PAGE_SIZE=15          # Items per page
declare -g NAV_BOUNDARY="/home"      # Can't navigate above this directory
declare -g NAV_TITLE="FILE BROWSER"  # Title to display
declare -g NAV_SINGLE_MARK_MODE=false # If true, only one file can be marked at a time
declare -g NAV_SHOW_HIDDEN=false     # If true, show hidden files/folders (starting with .)

# Check if a file is marked
is_file_marked() {
    local file_path="$1"
    local abs_path=$(realpath "$file_path" 2>/dev/null)
    for marked in "${MARKED_FILES[@]}"; do
        [ "$marked" = "$abs_path" ] && return 0
    done
    return 1
}

# Function to show path selection - goes straight to interactive browser
show_path_selector() {
    show_interactive_browser
}

# Function to show manual path entry (existing behavior)
show_manual_path_entry() {
    clear
    print_header "MANUAL PATH ENTRY"
    echo ""

    local projects_dir=""
    while [ -z "$projects_dir" ]; do
        read -p "Enter the relative path to your projects folder: " projects_dir

        if [ -z "$projects_dir" ]; then
            print_error "Please enter a valid path"
            continue
        fi

        # Convert to relative path if absolute path was provided
        if [[ "$projects_dir" = /* ]]; then
            projects_dir=$(realpath --relative-to="." "$projects_dir")
            print_step "Converted to relative path: $projects_dir"
        fi

        # Validate the directory
        if [ ! -d "$projects_dir" ]; then
            print_error "Directory '$projects_dir' does not exist!"
            projects_dir=""
            continue
        fi

        break
    done

    export SELECTED_PROJECTS_DIR="$projects_dir"
}

# Function to show interactive filesystem browser
# Parameters: mode (optional) - "directory" (default) or "files"
#             start_dir (optional) - starting directory (default: $HOME)
#             boundary_dir (optional) - can't navigate above this (default: /home)
#             title (optional) - browser title (default: "FILE BROWSER" or "DIRECTORY BROWSER")
#             single_mark_mode (optional) - "true" or "false" (default: false)
#             show_hidden (optional) - "true" or "false" (default: false)
show_interactive_browser() {
    BROWSER_MODE="${1:-directory}"
    local current_dir="${2:-$HOME}"
    NAV_BOUNDARY="${3:-/home}"
    local title="${4:-}"
    NAV_SINGLE_MARK_MODE="${5:-false}"
    NAV_SHOW_HIDDEN="${6:-false}"

    # Set default title based on mode if not provided
    if [ -z "$title" ]; then
        if [ "$BROWSER_MODE" = "files" ]; then
            NAV_TITLE="FILE BROWSER"
        else
            NAV_TITLE="DIRECTORY BROWSER"
        fi
    else
        NAV_TITLE="$title"
    fi

    CURRENT_SELECTION=1
    NAV_PAGE=1
    MARKED_FILES=()

    local need_full_redraw=true

    while true; do
        if [ "$need_full_redraw" = true ]; then
            # Show current directory and its contents
            show_directory_listing "$current_dir"

            # In browsing mode - capture single keystrokes
            if [ "$BROWSER_MODE" = "files" ]; then
                if [ "$NAV_SINGLE_MARK_MODE" = "true" ]; then
                    echo -e "${BRIGHT_YELLOW}↑ w  ↓ s${NC} navigate    ${BRIGHT_CYAN}[ ]${NC} page    ${BRIGHT_CYAN}#${NC} go to    ${BRIGHT_GREEN}enter${NC} open    ${BRIGHT_PURPLE}m${NC} mark    ${BRIGHT_BLUE}space${NC} confirm    ${BRIGHT_CYAN}c${NC} create    ${BRIGHT_PURPLE}b${NC} back    ${BRIGHT_PURPLE}h${NC} help"
                else
                    echo -e "${BRIGHT_YELLOW}↑ w  ↓ s${NC} navigate    ${BRIGHT_CYAN}[ ]${NC} page    ${BRIGHT_CYAN}#${NC} go to    ${BRIGHT_GREEN}enter${NC} open    ${BRIGHT_PURPLE}m${NC} mark    ${BRIGHT_CYAN}l${NC} list    ${BRIGHT_BLUE}space${NC} confirm    ${BRIGHT_CYAN}c${NC} create    ${BRIGHT_PURPLE}b${NC} back    ${BRIGHT_PURPLE}h${NC} help"
                fi
            else
                echo -e "${BRIGHT_YELLOW}↑ w  ↓ s${NC} navigate    ${BRIGHT_CYAN}[ ]${NC} page    ${BRIGHT_CYAN}#${NC} go to    ${BRIGHT_GREEN}enter${NC} open    ${BRIGHT_BLUE}space${NC} select    ${BRIGHT_CYAN}c${NC} create    ${BRIGHT_PURPLE}b${NC} back    ${BRIGHT_PURPLE}h${NC} help"
            fi
        fi

        IFS= read -r -n1 -s choice

        handle_browsing_key "$choice" "$current_dir"
        local result=$?

        need_full_redraw=true  # Default to full redraw

        if [ $result -eq 1 ]; then
            # Directory selected
            printf '\033[?25h'  # Restore cursor
            break
        elif [ $result -eq 2 ]; then
            # Return requested
            printf '\033[?25h'  # Restore cursor
            return
        elif [ $result -eq 4 ]; then
            # Navigate to parent directory
            current_dir=$(realpath "$current_dir/..")
            CURRENT_SELECTION=1
            NAV_PAGE=1
        elif [ $result -eq 5 ]; then
            # Navigate into selected directory using global array
            local selected_index=$((CURRENT_SELECTION - 1))
            local selected_dir="${NAV_DIRECTORIES[selected_index]}"

            if [ -n "$selected_dir" ] && [ -d "$selected_dir" ]; then
                current_dir=$(realpath "$selected_dir")
                CURRENT_SELECTION=1
                NAV_PAGE=1
            fi
        elif [ $result -eq 6 ]; then
            # Partial update - just redraw changed lines
            update_selection_display "$PREVIOUS_SELECTION" "$CURRENT_SELECTION"
            need_full_redraw=false
        elif [ $result -eq 7 ]; then
            # Partial page update - redraw paginator + list only
            update_page_display
            need_full_redraw=false
        elif [ $result -eq 8 ]; then
            # No-op - skip redraw entirely
            need_full_redraw=false
        fi
    done
}
