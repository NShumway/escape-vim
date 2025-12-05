" DEFEAT Screen for Escape Vim
" Full-screen defeat display (2 seconds)

" ============================================================================
" State
" ============================================================================

let s:defeat_bufnr = -1

" Defeat banner (ASCII art)
let s:defeat_banner = []
call add(s:defeat_banner, '        ██████╗ ███████╗███████╗███████╗ █████╗ ████████╗███████╗██████╗ ')
call add(s:defeat_banner, '        ██╔══██╗██╔════╝██╔════╝██╔════╝██╔══██╗╚══██╔══╝██╔════╝██╔══██╗')
call add(s:defeat_banner, '        ██║  ██║█████╗  █████╗  █████╗  ███████║   ██║   █████╗  ██║  ██║')
call add(s:defeat_banner, '        ██║  ██║██╔══╝  ██╔══╝  ██╔══╝  ██╔══██║   ██║   ██╔══╝  ██║  ██║')
call add(s:defeat_banner, '        ██████╔╝███████╗██║     ███████╗██║  ██║   ██║   ███████╗██████╔╝')
call add(s:defeat_banner, '        ╚═════╝ ╚══════╝╚═╝     ╚══════╝╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═════╝ ')

" ============================================================================
" Buffer Management
" ============================================================================

function! s:GetBuffer()
  let s:defeat_bufnr = Util_GetScratchBuffer(s:defeat_bufnr)
  return s:defeat_bufnr
endfunction

" ============================================================================
" Rendering
" ============================================================================

" Generate the defeat screen content
function! s:GenerateScreen(width, height)
  " Initialize empty canvas
  let l:canvas = []
  for i in range(a:height)
    call add(l:canvas, repeat(' ', a:width))
  endfor

  " Add defeat banner in center
  " Calculate banner_x once using first line to ensure consistent alignment
  let l:banner_y = (a:height / 2) - 3
  let l:banner_x = (a:width - strdisplaywidth(s:defeat_banner[0])) / 2
  if l:banner_x < 0
    let l:banner_x = 0
  endif
  for l:idx in range(len(s:defeat_banner))
    let l:banner_line = s:defeat_banner[l:idx]
    let l:y = l:banner_y + l:idx
    if l:y >= 0 && l:y < a:height
      let l:canvas[l:y] = strpart(repeat(' ', l:banner_x), 0, l:banner_x) . l:banner_line
    endif
  endfor

  " Add subtitle below banner
  let l:subtitle = 'You did not reach the exit...'
  let l:sub_x = (a:width - len(l:subtitle)) / 2
  let l:sub_y = l:banner_y + len(s:defeat_banner) + 2
  if l:sub_y < a:height
    let l:canvas[l:sub_y] = strpart(repeat(' ', l:sub_x), 0, l:sub_x) . l:subtitle
  endif

  return l:canvas
endfunction

" ============================================================================
" Defeat Control
" ============================================================================

" Start the defeat screen
function! Defeat_Start()
  " Hide sideport for full-screen effect
  call Sideport_Hide()

  " Switch to defeat buffer
  let l:bufnr = s:GetBuffer()
  execute 'buffer ' . l:bufnr

  " Generate and render content
  let l:width = &columns
  let l:height = &lines - 1  " Leave room for command line
  let l:content = s:GenerateScreen(l:width, l:height)

  call setbufvar(l:bufnr, '&modifiable', 1)
  call deletebufline(l:bufnr, 1, '$')
  call setbufline(l:bufnr, 1, l:content)
  call setbufvar(l:bufnr, '&modifiable', 0)

  " Configure display
  setlocal nomodifiable
  setlocal nonumber
  setlocal norelativenumber
  setlocal nocursorline
  setlocal nocursorcolumn

  " Block all input during display (timed screen, no interaction needed)
  call UI_BlockAll()
  call UI_SetupQuit()

  redraw!
endfunction

" Stop the defeat screen (cleanup)
function! Defeat_Stop()
  " Nothing specific to clean up (no timers like fireworks)
endfunction
