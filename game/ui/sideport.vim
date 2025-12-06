" Sideport Rendering for Escape Vim
" Handles the left panel with Commander portrait and contextual info

" ============================================================================
" Configuration
" ============================================================================

" Sideport dimensions (~45% of screen width, min 44)
let s:sideport_bufnr = -1

function! s:GetSideportWidth()
  let l:width = float2nr(&columns * 0.45)
  return max([l:width, 44])
endfunction

" Commander portrait (loaded from file)
let s:commander_portrait = []

" ============================================================================
" Portrait Loading
" ============================================================================

" Load the Commander portrait from file
function! s:LoadPortrait()
  let l:path = 'assets/commander.txt'
  if filereadable(l:path)
    let s:commander_portrait = readfile(l:path)
  else
    let s:commander_portrait = ['[Commander Portrait Not Found]']
  endif
endfunction

" ============================================================================
" Buffer Management
" ============================================================================

" Create or get the sideport buffer
" @return: buffer number
function! Sideport_GetBuffer()
  let s:sideport_bufnr = Util_GetScratchBuffer(s:sideport_bufnr)
  return s:sideport_bufnr
endfunction

" Show the sideport as a vertical split
function! Sideport_Show()
  " Load portrait if not loaded
  if empty(s:commander_portrait)
    call s:LoadPortrait()
  endif

  let l:bufnr = Sideport_GetBuffer()

  " Check if sideport window already exists
  let l:winnr = bufwinnr(l:bufnr)
  if l:winnr > 0
    " Sideport already visible, just switch to it briefly to ensure it's set up
    execute l:winnr . 'wincmd w'
  else
    " Create vertical split on the left
    execute 'topleft vertical ' . s:GetSideportWidth() . 'split'
    execute 'buffer ' . l:bufnr
  endif

  " Lock the window
  setlocal nomodifiable
  setlocal nonumber
  setlocal norelativenumber
  setlocal nocursorline
  setlocal nocursorcolumn
  setlocal signcolumn=no
  setlocal winfixwidth

  " Block all input in sideport (focus should be on main window)
  call UI_BlockAll()
  call UI_SetupQuit()

  " Return focus to main window
  wincmd l
endfunction

" Hide the sideport (for full-screen modes like FIREWORKS)
function! Sideport_Hide()
  let l:winnr = bufwinnr(s:sideport_bufnr)
  if l:winnr > 0
    execute l:winnr . 'wincmd w'
    close
  endif
endfunction

" ============================================================================
" Content Rendering
" ============================================================================

" Clear and set sideport content
" @param lines: list of strings to display
function! Sideport_SetContent(lines)
  let l:bufnr = Sideport_GetBuffer()

  call setbufvar(l:bufnr, '&modifiable', 1)
  call deletebufline(l:bufnr, 1, '$')
  call setbufline(l:bufnr, 1, a:lines)
  call setbufvar(l:bufnr, '&modifiable', 0)
endfunction

" ============================================================================
" Rendering Modes
" ============================================================================

" Render Mode 1: LORE (portrait + quote only)
" @param quote: commander quote string (can contain \n)
function! Sideport_RenderLore(quote)
  let l:lines = []

  " Add portrait
  let l:lines += s:commander_portrait

  " Add title
  call add(l:lines, '')
  call add(l:lines, '        T H E   C O M M A N D E R')
  call add(l:lines, '')

  " Add separator
  call add(l:lines, repeat('─', s:GetSideportWidth()))
  call add(l:lines, '')

  " Add quote (split on newlines)
  let l:quote_lines = split(a:quote, '\n')
  for l:line in l:quote_lines
    call add(l:lines, '  ' . l:line)
  endfor
  call add(l:lines, '')
  call add(l:lines, '                     — The Commander')
  call add(l:lines, '')

  call Sideport_SetContent(l:lines)
endfunction

" Render Mode 2: GAMEPLAY (full info panel)
" @param level_num: level number
" @param level_title: level title string
" @param objective: objective text
" @param commands: list of command dictionaries
" @param time_str: formatted time string (e.g., "00:00")
" @param moves: move count
function! Sideport_RenderGameplay(level_num, level_title, objective, commands, time_str, moves)
  let l:lines = []

  " Add portrait
  let l:lines += s:commander_portrait

  " Add title
  call add(l:lines, '')
  call add(l:lines, '        T H E   C O M M A N D E R')
  call add(l:lines, '')

  " Separator
  call add(l:lines, repeat('─', s:GetSideportWidth()))

  " Level info
  call add(l:lines, '  LEVEL ' . a:level_num . ': ' . a:level_title)
  call add(l:lines, '')

  " Objective
  call add(l:lines, '  OBJECTIVE')
  call add(l:lines, '  ' . a:objective)
  call add(l:lines, '')

  " Separator
  call add(l:lines, repeat('─', s:GetSideportWidth()))

  " Commands
  call add(l:lines, '  COMMANDS')
  call add(l:lines, '  ' . repeat('─', 8))

  for l:cmd in a:commands
    let l:key_padded = printf('%-4s', l:cmd.key)
    call add(l:lines, '  ' . l:key_padded . l:cmd.desc)
  endfor

  call add(l:lines, '')

  " Separator
  call add(l:lines, repeat('─', s:GetSideportWidth()))

  " Timer and moves
  call add(l:lines, '')
  call add(l:lines, '  TIME      ' . a:time_str . '        MOVES  ' . a:moves)
  call add(l:lines, '')

  call Sideport_SetContent(l:lines)
endfunction

" Render Mode 3: RESULTS (portrait + victory quote)
" @param victory_quote: commander victory quote string
function! Sideport_RenderResults(victory_quote)
  let l:lines = []

  " Add portrait
  let l:lines += s:commander_portrait

  " Add title
  call add(l:lines, '')
  call add(l:lines, '        T H E   C O M M A N D E R')
  call add(l:lines, '')

  " Add separator
  call add(l:lines, repeat('─', s:GetSideportWidth()))
  call add(l:lines, '')

  " Add victory quote (split on newlines)
  let l:quote_lines = split(a:victory_quote, '\n')
  for l:line in l:quote_lines
    call add(l:lines, '  ' . l:line)
  endfor
  call add(l:lines, '')
  call add(l:lines, '                     — The Commander')
  call add(l:lines, '')

  " Separator
  call add(l:lines, repeat('─', s:GetSideportWidth()))
  call add(l:lines, '')
  call add(l:lines, '         Press <Enter> to continue')
  call add(l:lines, '')

  call Sideport_SetContent(l:lines)
endfunction

" ============================================================================
" Timer Update (for gameplay) - uses tick system
" ============================================================================

" Start the timer update loop (subscribes to tick system)
function! Sideport_StartTimer()
  " Subscribe to tick system: 20 ticks = 1 second
  call Tick_Subscribe('gameplay:sideport', function('s:OnTick'), 20)
endfunction

" Internal: Tick callback for timer display update
" @param tick: current tick number
" @return: 1 to stay subscribed
function! s:OnTick(tick)
  let l:elapsed = Gameplay_GetElapsed()
  let l:time_str = Util_FormatTime(l:elapsed)

  " Re-render the gameplay sideport
  let l:meta = Game_GetLevelMeta()
  let l:commands = Game_GetAllCommands()
  call Sideport_RenderGameplay(
        \ Game_GetLevelId(),
        \ get(l:meta, 'title', 'Unknown'),
        \ get(l:meta, 'objective', ''),
        \ l:commands,
        \ l:time_str,
        \ Gameplay_GetMoves()
        \ )

  return 1  " Stay subscribed
endfunction

