" Viewport System for Escape Vim
" Handles terminal resizing and player-centered camera

" ============================================================================
" Viewport Configuration
" ============================================================================

let s:viewport_lines = 24
let s:viewport_cols = 80
let s:pad_top = 0
let s:pad_left = 0

" ============================================================================
" Terminal Resize
" ============================================================================

" Set the viewport size (terminal dimensions)
" @param lines: number of rows
" @param cols: number of columns
function! ViewportSetSize(lines, cols)
  let s:viewport_lines = a:lines
  let s:viewport_cols = a:cols

  " Resize terminal window
  execute 'set lines=' . a:lines
  execute 'set columns=' . a:cols
endfunction

" ============================================================================
" Buffer Padding
" ============================================================================

" Pad the current buffer so player can always be centered
" Adds empty lines above/below and spaces left/right
" Returns the padding offsets [top, left] for adjusting positions
function! ViewportPadBuffer()
  " Calculate padding needed (half viewport size)
  let s:pad_top = s:viewport_lines / 2
  let s:pad_left = s:viewport_cols / 2

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

  " Add empty lines at bottom
  if s:pad_top > 0
    let l:blank_line = repeat(' ', s:pad_left)
    let l:bottom_lines = repeat([l:blank_line], s:pad_top)
    call append('$', l:bottom_lines)
  endif

  setlocal nomodifiable

  return [s:pad_top, s:pad_left]
endfunction

" Get the current padding offsets
function! ViewportGetPadding()
  return [s:pad_top, s:pad_left]
endfunction

" ============================================================================
" Player-Centered Camera
" ============================================================================

" Enable player-centered scrolling
" Uses scrolloff to keep the player centered in the viewport
function! ViewportEnableCenter()
  " Center cursor vertically - keeps player in middle of screen
  set scrolloff=999

  " Center cursor horizontally - keeps player in middle for wide mazes
  set sidescroll=1
  set sidescrolloff=999

  " Required for horizontal scrolling to work
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
" @param meta: dictionary containing 'viewport' key with 'lines' and 'cols'
function! ViewportInit(meta)
  if has_key(a:meta, 'viewport')
    let l:vp = a:meta.viewport
    let l:lines = get(l:vp, 'lines', 24)
    let l:cols = get(l:vp, 'cols', 80)
    call ViewportSetSize(l:lines, l:cols)
  endif

  " Always enable centering for game levels
  call ViewportEnableCenter()
endfunction
