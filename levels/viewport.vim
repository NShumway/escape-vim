" Viewport System for Escape Vim
" Handles terminal resizing and player-centered camera

" ============================================================================
" Viewport Configuration
" ============================================================================

let s:viewport_lines = 24
let s:viewport_cols = 80
let s:maze_lines = 0
let s:maze_cols = 0
let s:pad_top = 0
let s:pad_left = 0
let s:scroll_mode = 1  " 1 = scroll (large maze), 0 = static (small maze)

" Check if resize is disabled (UI flow sets this via UI_IsResizeDisabled)
function! s:IsResizeDisabled()
  return exists('*UI_IsResizeDisabled') && UI_IsResizeDisabled()
endfunction

" ============================================================================
" Terminal Resize
" ============================================================================

" Set the viewport size (terminal dimensions)
" @param lines: number of rows
" @param cols: number of columns
function! ViewportSetSize(lines, cols)
  let s:viewport_lines = a:lines
  let s:viewport_cols = a:cols

  " Resize terminal window (unless disabled by UI flow)
  if !s:IsResizeDisabled()
    execute 'set lines=' . a:lines
    execute 'set columns=' . a:cols
  endif
endfunction

" ============================================================================
" Buffer Padding
" ============================================================================

" Measure the current buffer dimensions (before any padding)
" @return: [lines, max_cols] where max_cols is the widest line
function! s:MeasureBuffer()
  let l:lines = line('$')
  let l:max_cols = 0
  for l:i in range(1, l:lines)
    let l:len = strchars(getline(l:i))
    if l:len > l:max_cols
      let l:max_cols = l:len
    endif
  endfor
  return [l:lines, l:max_cols]
endfunction

" Pad the current buffer based on maze vs viewport size
" - Static mode (small maze): center the maze in viewport, no scrolling
" - Scroll mode (large maze): pad so player can reach center at edges
" Returns the padding offsets [top, left] for adjusting positions
function! ViewportPadBuffer()
  " Use stored maze dimensions from metadata, or measure if not set
  if s:maze_lines > 0 && s:maze_cols > 0
    let l:maze_lines = s:maze_lines
    let l:maze_cols = s:maze_cols
  else
    let l:maze_size = s:MeasureBuffer()
    let l:maze_lines = l:maze_size[0]
    let l:maze_cols = l:maze_size[1]
  endif

  " Determine mode based on whether maze fits in viewport
  if l:maze_lines <= s:viewport_lines && l:maze_cols <= s:viewport_cols
    " Static mode: maze fits entirely in viewport
    let s:scroll_mode = 0

    " Center the maze in the viewport
    let s:pad_top = (s:viewport_lines - l:maze_lines) / 2
    let s:pad_left = (s:viewport_cols - l:maze_cols) / 2
  else
    " Scroll mode: maze larger than viewport
    let s:scroll_mode = 1

    " Pad by half viewport so player can reach center at all edges
    let s:pad_top = s:viewport_lines / 2
    let s:pad_left = s:viewport_cols / 2
  endif

  " Need to make buffer modifiable temporarily
  setlocal modifiable

  " Pad each existing line with leading spaces
  if s:pad_left > 0
    let l:padding = repeat(' ', s:pad_left)
    silent! execute '%s/^/' . l:padding . '/'
  endif

  " Add empty lines at top
  if s:pad_top > 0
    let l:blank_line = repeat(' ', s:pad_left)
    let l:top_lines = repeat([l:blank_line], s:pad_top)
    call append(0, l:top_lines)
  endif

  " Add empty lines at bottom (only needed for scroll mode)
  if s:scroll_mode && s:pad_top > 0
    let l:blank_line = repeat(' ', s:pad_left)
    let l:bottom_lines = repeat([l:blank_line], s:pad_top)
    call append('$', l:bottom_lines)
  endif

  setlocal nomodifiable

  " Apply the appropriate scrolling mode
  if s:scroll_mode
    call ViewportEnableCenter()
  else
    call ViewportEnableStatic()
  endif

  return [s:pad_top, s:pad_left]
endfunction

" Get the current padding offsets
function! ViewportGetPadding()
  return [s:pad_top, s:pad_left]
endfunction

" ============================================================================
" Player-Centered Camera
" ============================================================================

" Enable player-centered scrolling (for scroll mode)
" Uses scrolloff to keep the player centered in the viewport
" Called automatically by ViewportPadBuffer based on mode
function! ViewportEnableCenter()
  " Center cursor vertically - keeps player in middle of screen
  set scrolloff=999

  " Center cursor horizontally - keeps player in middle for wide mazes
  set sidescroll=1
  set sidescrolloff=999

  " Required for horizontal scrolling to work
  set nowrap
endfunction

" Enable static display (for static mode)
" No scrolling - the whole maze is visible
function! ViewportEnableStatic()
  set scrolloff=0
  set sidescrolloff=0
  set nowrap
endfunction

" Disable centered scrolling (restore defaults)
function! ViewportDisableCenter()
  set scrolloff=0
  set sidescrolloff=0
endfunction

" ============================================================================
" Initialization from Level Meta
" ============================================================================

" Initialize viewport from a level's meta dictionary
" @param meta: dictionary containing 'viewport' and 'maze' keys
function! ViewportInit(meta)
  " Set viewport (terminal) size
  if has_key(a:meta, 'viewport')
    let l:vp = a:meta.viewport
    let l:lines = get(l:vp, 'lines', 24)
    let l:cols = get(l:vp, 'cols', 80)
    call ViewportSetSize(l:lines, l:cols)
  endif

  " Store maze dimensions for ViewportPadBuffer
  if has_key(a:meta, 'maze')
    let l:maze = a:meta.maze
    let s:maze_lines = get(l:maze, 'lines', 0)
    let s:maze_cols = get(l:maze, 'cols', 0)
  else
    " Fallback: will measure buffer in ViewportPadBuffer
    let s:maze_lines = 0
    let s:maze_cols = 0
  endif
endfunction
