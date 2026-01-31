# omni-navigator

Interactive terminal filesystem browser for **bash**. Provides directory and file browsing with pagination, keyboard navigation, file marking, and directory creation.

**Requires bash.** Uses bash-specific features (`read -n`, `declare -g`, `local -n` namerefs) that are not compatible with zsh.

## Dependencies

Requires [omni-ui-kit](../omni-ui-kit/) (color variables and UI functions like `print_header`, `print_color`, etc).

## Standalone usage

Must be run from a bash shell. If your default shell is zsh, start bash first.

```bash
# From bash (run `bash` first if you're in zsh)
source libs/omni-ui-kit/index.sh && source libs/omni-navigator/index.sh

# Directory browser (default)
show_interactive_browser

# File browser
show_interactive_browser "files"
```

One-liner from any shell:

```bash
bash -ic 'source libs/omni-ui-kit/index.sh && source libs/omni-navigator/index.sh && show_interactive_browser'
```

After the browser exits, check these globals for the result:

- **Directory mode** - `$SELECTED_PROJECTS_DIR` contains the selected absolute path
- **File mode** - `${MARKED_FILES[@]}` array contains absolute paths of marked files

## API

### `show_interactive_browser`

Main entry point. All parameters are positional and optional:

```
show_interactive_browser [mode] [start_dir] [boundary] [title] [single_mark] [show_hidden]
```

| Param | Default | Description |
|-------|---------|-------------|
| `mode` | `"directory"` | `"directory"` or `"files"` |
| `start_dir` | `$HOME` | Initial directory to open |
| `boundary` | `/home` | Navigation ceiling (can't go above this) |
| `title` | auto | Header title. Auto-sets to `FILE BROWSER` or `DIRECTORY BROWSER` |
| `single_mark` | `false` | `"true"` limits file marking to one file at a time |
| `show_hidden` | `false` | `"true"` shows dotfiles/dotdirs |

### `show_path_selector`

Convenience wrapper — calls `show_interactive_browser` with all defaults.

### `show_manual_path_entry`

Fallback text prompt for manual path input. Sets `$SELECTED_PROJECTS_DIR`.

### `is_file_marked`

```bash
is_file_marked "/path/to/file"  # returns 0 (true) or 1 (false)
```

## Keybindings

| Key | Action |
|-----|--------|
| `w` / `up` | Move selection up |
| `s` / `down` | Move selection down |
| `enter` | Open directory |
| `space` | Confirm selection (directory mode: select cwd, file mode: confirm marked files) |
| `[` / `]` | Previous / next page |
| `0-9` | Jump to item by number |
| `m` | Mark/unmark file (file mode only) |
| `l` | List marked files (file mode, multi-mark only) |
| `c` | Create new directory |
| `b` / `ESC` | Go back / cancel |
| `h` | Show help |

## File structure

```
omni-navigator/
  index.sh   — public API + state globals
  render.sh  — display and rendering (directory listing, pagination)
  input.sh   — keyboard handling and actions
```

## State globals

These are set internally during browsing and can be read after the browser exits:

| Variable | Type | Description |
|----------|------|-------------|
| `CURRENT_SELECTION` | int | Currently highlighted item (1-indexed) |
| `NAV_DIRECTORIES` | array | Absolute paths of listed items |
| `NAV_DISPLAY_NAMES` | array | Display names for each item |
| `NAV_ITEM_TYPES` | array | `"dir"` or `"file"` per item |
| `MARKED_FILES` | array | Absolute paths of marked files |
| `BROWSER_MODE` | string | Current mode (`"directory"` or `"files"`) |
| `NAV_PAGE` | int | Current page number |
| `NAV_PAGE_SIZE` | int | Items per page (default: 15) |
| `NAV_BOUNDARY` | string | Navigation ceiling path |

## Examples

```bash
# Pick a project directory starting from ~/projects
show_interactive_browser "directory" "$HOME/projects" "$HOME"
echo "Selected: $SELECTED_PROJECTS_DIR"

# Pick config files from /etc, single selection, show hidden
show_interactive_browser "files" "/etc" "/" "CONFIG FILES" "true" "true"
echo "Selected: ${MARKED_FILES[0]}"

# Multi-file selection
show_interactive_browser "files" "$HOME/documents" "$HOME" "SELECT FILES"
for f in "${MARKED_FILES[@]}"; do
    echo "Marked: $f"
done
```
