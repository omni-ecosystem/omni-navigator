#!/bin/bash

# ========================================
# Filesystem Navigator Rendering
# ========================================
# Display and rendering functions
# Usage: source libs/navigator/render.sh

# Function to render a single directory line
# Parameters: index (0-based), is_selected (0 or 1)
render_directory_line() {
    local index="$1"
    local is_selected="$2"
    local counter=$((index + 1))
    local item_name="${NAV_DISPLAY_NAMES[index]}"
    local item_type="${NAV_ITEM_TYPES[index]:-dir}"
    local item_path="${NAV_DIRECTORIES[index]}"
    local icon=""
    local mark=""

    # Choose appropriate icon
    if [[ "$item_name" == ".. (parent directory)" ]]; then
        icon="⬆️ "
    elif [ "$item_type" = "file" ]; then
        icon="📄 "
        # Show mark indicator for files in file mode
        if [ "$BROWSER_MODE" = "files" ] && is_file_marked "$item_path"; then
            mark="${BRIGHT_GREEN}●${NC} "
        fi
    else
        icon="📂 "
    fi

    if [ "$is_selected" -eq 1 ]; then
        # Highlight current selection with arrow
        printf "  ${BRIGHT_YELLOW}▶ %-2s${NC}  ${mark}${icon}${BRIGHT_YELLOW}%s${NC}" "$counter" "$item_name"
    else
        # Normal entry
        printf "    ${BRIGHT_CYAN}%-2s${NC}  ${mark}${icon}${BRIGHT_WHITE}%s${NC}" "$counter" "$item_name"
    fi
}

# Function to update selection display without full redraw
update_selection_display() {
    local old_sel="$1"
    local new_sel="$2"

    printf '\033[?25l'  # Hide cursor

    # Calculate page-relative positions (1-indexed within page)
    local page_start=$(( (NAV_PAGE - 1) * NAV_PAGE_SIZE + 1 ))
    local old_page_pos=$((old_sel - page_start + 1))
    local new_page_pos=$((new_sel - page_start + 1))

    # Move to old selection line and redraw as unselected
    local old_line=$((NAV_LIST_START_LINE + old_page_pos - 1))
    printf '\033[%d;1H' "$old_line"  # Move to line
    render_directory_line $((old_sel - 1)) 0
    printf '\033[K'  # Clear any trailing characters

    # Move to new selection line and redraw as selected
    local new_line=$((NAV_LIST_START_LINE + new_page_pos - 1))
    printf '\033[%d;1H' "$new_line"  # Move to line
    render_directory_line $((new_sel - 1)) 1
    printf '\033[K'  # Clear any trailing characters

    # Move cursor below menu line (fixed height: list + blank + menu + 1)
    local input_line=$((NAV_LIST_START_LINE + NAV_PAGE_SIZE + 2))
    printf '\033[%d;1H' "$input_line"
}

# Function to update page display without full redraw (paginator + list only)
update_page_display() {
    printf '\033[?25l'  # Hide cursor

    local total_items=${#NAV_DIRECTORIES[@]}
    local total_pages=$(( (total_items + NAV_PAGE_SIZE - 1) / NAV_PAGE_SIZE ))
    local start_index=$(( (NAV_PAGE - 1) * NAV_PAGE_SIZE ))
    local end_index=$(( start_index + NAV_PAGE_SIZE - 1 ))
    [ "$end_index" -ge "$total_items" ] && end_index=$((total_items - 1))

    # Move to page indicator line (NAV_LIST_START_LINE - 2)
    local page_line=$((NAV_LIST_START_LINE - 2))
    printf '\033[%d;1H\033[K' "$page_line"

    # Redraw page indicator
    local first_item=$((start_index + 1))
    local last_item=$((end_index + 1))
    local marked_info=""
    if [ "$BROWSER_MODE" = "files" ] && [ ${#MARKED_FILES[@]} -gt 0 ]; then
        if [ "$NAV_SINGLE_MARK_MODE" = "true" ]; then
            local marked_file=$(basename "${MARKED_FILES[0]}")
            marked_info="  ${BRIGHT_GREEN}●${NC} ${BRIGHT_WHITE}${marked_file}${NC} ${DIM}selected${NC}"
        else
            marked_info="  ${BRIGHT_GREEN}● ${#MARKED_FILES[@]} files marked${NC}"
        fi
    fi
    echo -e "${NC}Page ${NAV_PAGE}/${total_pages}  [${first_item}-${last_item} of ${total_items}]${marked_info}${NC}"

    # Skip blank line (already exists)
    printf '\033[%d;1H' "$NAV_LIST_START_LINE"

    # Redraw all list lines
    local items_on_page=$((end_index - start_index + 1))
    for (( i=start_index; i<=end_index; i++ )); do
        local is_selected=0
        [[ $((i + 1)) -eq "$CURRENT_SELECTION" ]] && is_selected=1
        render_directory_line "$i" "$is_selected"
        printf '\033[K'  # Clear trailing characters
        echo ""
    done

    # Clear padding lines
    local padding=$((NAV_PAGE_SIZE - items_on_page))
    for (( p=0; p<padding; p++ )); do
        printf '\033[K\n'
    done

    # Move cursor below menu line
    local input_line=$((NAV_LIST_START_LINE + NAV_PAGE_SIZE + 2))
    printf '\033[%d;1H' "$input_line"
}

# Function to show directory listing
show_directory_listing() {
    local dir="$1"

    printf '\033[?25l'  # Hide cursor during redraw
    clear
    print_header "$NAV_TITLE"
    echo ""
    local absolute_path=$(realpath "$dir")
    local display_path="${absolute_path/#$HOME/\~}"
    print_color "$BRIGHT_CYAN" "Current location: ${BRIGHT_WHITE}${display_path}${NC}"
    echo ""

    # Clear and populate global arrays
    NAV_DIRECTORIES=()
    NAV_DISPLAY_NAMES=()
    NAV_ITEM_TYPES=()

    # Add parent directory option (don't go above NAV_BOUNDARY)
    local current_real_path=$(realpath "$dir")
    local boundary_real_path=$(realpath "$NAV_BOUNDARY" 2>/dev/null || echo "$NAV_BOUNDARY")
    local can_go_up=false
    [ "$current_real_path" != "$boundary_real_path" ] && can_go_up=true

    if [ "$can_go_up" = true ]; then
        NAV_DIRECTORIES+=("$dir/..")
        NAV_DISPLAY_NAMES+=(".. (parent directory)")
        NAV_ITEM_TYPES+=("dir")
    fi

    if [ "$BROWSER_MODE" = "files" ]; then
        # File mode: show directories first, then files (including hidden)
        while IFS= read -r -d '' item; do
            local basename_item=$(basename "$item")
            if [ -d "$item" ]; then
                NAV_DIRECTORIES+=("$item")
                NAV_DISPLAY_NAMES+=("$basename_item/")
                NAV_ITEM_TYPES+=("dir")
            fi
        done < <(find "$dir" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)

        while IFS= read -r -d '' item; do
            local basename_item=$(basename "$item")
            NAV_DIRECTORIES+=("$item")
            NAV_DISPLAY_NAMES+=("$basename_item")
            NAV_ITEM_TYPES+=("file")
        done < <(find "$dir" -mindepth 1 -maxdepth 1 -type f -print0 2>/dev/null | sort -z)
    else
        # Directory mode: only directories, optionally skip hidden
        while IFS= read -r -d '' subdir; do
            if [ -d "$subdir" ]; then
                local basename_dir=$(basename "$subdir")
                # Skip hidden folders unless NAV_SHOW_HIDDEN is true
                if [[ "$NAV_SHOW_HIDDEN" == "true" ]] || [[ ! "$basename_dir" =~ ^\. ]]; then
                    NAV_DIRECTORIES+=("$subdir")
                    NAV_DISPLAY_NAMES+=("$basename_dir/")
                    NAV_ITEM_TYPES+=("dir")
                fi
            fi
        done < <(find "$dir" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)
    fi

    if [ ${#NAV_DIRECTORIES[@]} -eq 0 ]; then
        if [ "$BROWSER_MODE" = "files" ]; then
            print_warning "No items found in this location"
        else
            print_warning "No directories found in this location"
        fi
        echo ""
        echo -e "${BRIGHT_YELLOW}Press 'Space' to select current directory or 'b' to return${NC}"
        return
    fi

    # Pagination calculations
    local total_items=${#NAV_DIRECTORIES[@]}
    local total_pages=$(( (total_items + NAV_PAGE_SIZE - 1) / NAV_PAGE_SIZE ))

    # Clamp page to valid range
    [ "$NAV_PAGE" -lt 1 ] && NAV_PAGE=1
    [ "$NAV_PAGE" -gt "$total_pages" ] && NAV_PAGE=$total_pages

    # Calculate page bounds (0-indexed)
    local start_index=$(( (NAV_PAGE - 1) * NAV_PAGE_SIZE ))
    local end_index=$(( start_index + NAV_PAGE_SIZE - 1 ))
    [ "$end_index" -ge "$total_items" ] && end_index=$((total_items - 1))

    # Show page indicator
    local first_item=$((start_index + 1))
    local last_item=$((end_index + 1))
    local marked_info=""
    if [ "$BROWSER_MODE" = "files" ] && [ ${#MARKED_FILES[@]} -gt 0 ]; then
        if [ "$NAV_SINGLE_MARK_MODE" = "true" ]; then
            local marked_file=$(basename "${MARKED_FILES[0]}")
            marked_info="  ${BRIGHT_GREEN}●${NC} ${BRIGHT_WHITE}${marked_file}${NC} ${DIM}selected${NC}"
        else
            marked_info="  ${BRIGHT_GREEN}● ${#MARKED_FILES[@]} files marked${NC}"
        fi
    fi
    echo -e "${NC}Page ${NAV_PAGE}/${total_pages}  [${first_item}-${last_item} of ${total_items}]${marked_info}${NC}"
    echo ""

    # Display stylized list with icons (only current page)
    local items_on_page=$((end_index - start_index + 1))
    for (( i=start_index; i<=end_index; i++ )); do
        local is_selected=0
        [[ $((i + 1)) -eq "$CURRENT_SELECTION" ]] && is_selected=1
        render_directory_line "$i" "$is_selected"
        echo ""  # newline after each line
    done

    # Pad with empty lines to maintain fixed height
    local padding=$((NAV_PAGE_SIZE - items_on_page))
    for (( p=0; p<padding; p++ )); do
        echo ""
    done

    echo ""
}
