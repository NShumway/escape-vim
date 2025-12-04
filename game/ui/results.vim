" RESULTS Screen for Escape Vim
" Shows completion stats and leaderboard

" ============================================================================
" State
" ============================================================================

let s:results_bufnr = -1
let s:results_timer = -1
let s:star_frame = 0

" Mock leaderboard data
let s:mock_leaderboard = []
call add(s:mock_leaderboard, {'name': 'vimmaster', 'time': 34, 'moves': 18})
call add(s:mock_leaderboard, {'name': 'hjkl4life', 'time': 41, 'moves': 21})
call add(s:mock_leaderboard, {'name': 'escapeartist', 'time': 58, 'moves': 29})
call add(s:mock_leaderboard, {'name': 'quitwhileahead', 'time': 72, 'moves': 35})
call add(s:mock_leaderboard, {'name': 'nostruggle', 'time': 105, 'moves': 51})

" ============================================================================
" Buffer Management
" ============================================================================

function! s:GetBuffer()
  if s:results_bufnr < 0 || !bufexists(s:results_bufnr)
    let s:results_bufnr = bufadd('')
    call bufload(s:results_bufnr)

    call setbufvar(s:results_bufnr, '&buftype', 'nofile')
    call setbufvar(s:results_bufnr, '&bufhidden', 'hide')
    call setbufvar(s:results_bufnr, '&swapfile', 0)
    call setbufvar(s:results_bufnr, '&buflisted', 0)
  endif

  return s:results_bufnr
endfunction

" ============================================================================
" Rendering
" ============================================================================

" Render the RESULTS screen
function! Results_Render()
  " Show sideport with victory quote
  call Sideport_Show()
  let l:victory_quote = get(g:current_level_meta, 'victory_quote', 'Well done!')
  call Sideport_RenderResults(l:victory_quote)

  " Render main content
  call s:RenderMainArea()

  " Set up input
  call s:SetupInput()

  " Start subtle background animation
  let s:star_frame = 0
  let s:results_timer = timer_start(500, function('s:AnimateStars'), {'repeat': -1})
endfunction

" Render main content area
function! s:RenderMainArea()
  let l:bufnr = s:GetBuffer()
  let l:lines = []

  " Get player's final stats (stored at level completion, not live)
  let l:elapsed = g:game_final_time
  let l:moves = g:game_final_moves
  let l:time_str = s:FormatTime(l:elapsed)

  " Top area with subtle animated stars
  call add(l:lines, '')
  call add(l:lines, s:GenerateStarLine(s:star_frame, 0))
  call add(l:lines, s:GenerateStarLine(s:star_frame, 1))
  call add(l:lines, s:GenerateStarLine(s:star_frame, 2))
  call add(l:lines, '')

  " Mission accomplished banner
  call add(l:lines, '      ╔═══════════════════════════════╗')
  call add(l:lines, '      ║                               ║')
  call add(l:lines, '      ║     MISSION ACCOMPLISHED      ║')
  call add(l:lines, '      ║                               ║')
  call add(l:lines, '      ║     Level ' . g:current_level_id . ': ' . printf('%-17s', get(g:current_level_meta, 'title', 'Unknown')) . ' ║')
  call add(l:lines, '      ║                               ║')
  call add(l:lines, '      ╚═══════════════════════════════╝')
  call add(l:lines, '')
  call add(l:lines, '')

  " Player stats
  call add(l:lines, '      YOUR RESULTS')
  call add(l:lines, '      ' . repeat('─', 12))
  call add(l:lines, '      Time:    ' . l:time_str)
  call add(l:lines, '      Moves:   ' . l:moves)
  call add(l:lines, '')
  call add(l:lines, '')

  " Leaderboard
  call add(l:lines, '      LEADERBOARD')
  call add(l:lines, '      ' . repeat('─', 11))

  " Merge player into leaderboard
  let l:board = s:GetLeaderboardWithPlayer(l:elapsed, l:moves)
  let l:rank = 1
  for l:entry in l:board[:4]  " Top 5
    let l:time_fmt = s:FormatTime(l:entry.time)
    let l:name = printf('%-15s', l:entry.name)
    let l:is_you = (l:entry.name == 'YOU')
    let l:prefix = l:is_you ? '  >>  ' : '      '
    call add(l:lines, l:prefix . l:rank . '.  ' . l:name . l:time_fmt . '    ' . l:entry.moves)
    let l:rank += 1
  endfor

  call add(l:lines, '')

  " Set buffer content
  call setbufvar(l:bufnr, '&modifiable', 1)
  call deletebufline(l:bufnr, 1, '$')
  call setbufline(l:bufnr, 1, l:lines)
  call setbufvar(l:bufnr, '&modifiable', 0)

  " Switch to results buffer
  execute 'buffer ' . l:bufnr
  setlocal nomodifiable
  setlocal nonumber
  setlocal norelativenumber
  setlocal nocursorline
  setlocal nocursorcolumn
endfunction

" Generate a line with random stars for animation
function! s:GenerateStarLine(frame, row)
  let l:line = repeat(' ', 45)
  let l:star_positions = [[5, 15, 30], [10, 25, 40], [8, 20, 35]]
  let l:positions = l:star_positions[a:row % 3]

  for l:pos in l:positions
    " Toggle star visibility based on frame
    if (a:frame + l:pos) % 3 != 0
      let l:line = strpart(l:line, 0, l:pos) . '*' . strpart(l:line, l:pos + 1)
    endif
  endfor

  return l:line
endfunction

" Get leaderboard with player inserted at correct position
function! s:GetLeaderboardWithPlayer(time, moves)
  let l:board = copy(s:mock_leaderboard)
  let l:player = {'name': 'YOU', 'time': a:time, 'moves': a:moves}

  " Find insertion point (sorted by time)
  let l:idx = 0
  for l:entry in l:board
    if a:time < l:entry.time
      break
    endif
    let l:idx += 1
  endfor

  call insert(l:board, l:player, l:idx)
  return l:board
endfunction

" Format time as MM:SS
function! s:FormatTime(seconds)
  let l:mins = a:seconds / 60
  let l:secs = a:seconds % 60
  return printf('%02d:%02d', l:mins, l:secs)
endfunction

" ============================================================================
" Animation
" ============================================================================

function! s:AnimateStars(timer)
  if g:game_state != 'RESULTS'
    call s:StopAnimation()
    return
  endif

  let s:star_frame = (s:star_frame + 1) % 6
  call s:RenderMainArea()
endfunction

function! s:StopAnimation()
  if s:results_timer >= 0
    call timer_stop(s:results_timer)
    let s:results_timer = -1
  endif
endfunction

" ============================================================================
" Input Handling
" ============================================================================

function! s:SetupInput()
  " Any key to continue
  nnoremap <buffer> <silent> <CR> :call <SID>Continue()<CR>
  nnoremap <buffer> <silent> <Space> :call <SID>Continue()<CR>
  nnoremap <buffer> <silent> j :call <SID>Continue()<CR>
  nnoremap <buffer> <silent> k :call <SID>Continue()<CR>
  nnoremap <buffer> <silent> l :call <SID>Continue()<CR>
  nnoremap <buffer> <silent> h :call <SID>Continue()<CR>
endfunction

function! s:Continue()
  call s:StopAnimation()
  call Game_NextLevel()
endfunction
