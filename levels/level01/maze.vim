" Level 1: The Maze - Game Logic
" Wall collision detection, error state, and blocked commands

" ============================================================================
" State Variables
" ============================================================================

let s:last_valid_pos = [2, 2]  " [line, col], 1-indexed (start position)
let s:in_error_state = 0
let s:error_match_id = 0
let s:exit_row = 10
let s:exit_col = 27

" ============================================================================
" Highlight Groups
" ============================================================================

highlight ErrorCell cterm=reverse gui=reverse

" ============================================================================
" Wall Collision Detection
" ============================================================================

function! s:OnCursorMoved()
  " Always check current position
  let l:cur_line = line('.')
  let l:cur_col = col('.')
  let char = getline('.')[l:cur_col - 1]

  if char == '#'
    " On a wall - enter error state and bounce back
    call s:EnterErrorState(l:cur_line, l:cur_col)
  elseif !s:in_error_state
    " On valid ground and not in error cooldown - update last valid position
    let s:last_valid_pos = [l:cur_line, l:cur_col]
  endif
endfunction

function! s:EnterErrorState(wall_line, wall_col)
  " Ignore if already in error state (prevents re-entry during bounce)
  if s:in_error_state
    return
  endif

  let s:in_error_state = 1

  " Immediately bounce back to last valid position
  call cursor(s:last_valid_pos[0], s:last_valid_pos[1])

  " Visual: highlight the wall cell we hit
  let s:error_match_id = matchadd('ErrorCell', '\%' . a:wall_line . 'l\%' . a:wall_col . 'c.')

  " Clear error state after delay
  call timer_start(300, function('s:ExitErrorState'))
endfunction

function! s:ExitErrorState(timer_id)
  " Remove highlight
  if s:error_match_id
    silent! call matchdelete(s:error_match_id)
    let s:error_match_id = 0
  endif

  " Clear error state
  let s:in_error_state = 0
endfunction

" Set up the autocommands
augroup MazeGame
  autocmd!
  autocmd CursorMoved <buffer> call s:OnCursorMoved()
  " Clear command line after any command (helps hide blocked :q)
  autocmd CmdlineLeave <buffer> redraw!
augroup END

" ============================================================================
" Blocked Commands
" ============================================================================

" Central block function - designed for future "nice try" messaging
" @param cmd_name: string identifying the blocked command (e.g., "search", "arrow")
function! g:GameBlockCommand(cmd_name)
  " For now: silent no-op
  " Future: call side panel to show "Nice try! Use hjkl to move."
  return ''
endfunction

" Arrow keys
nnoremap <buffer> <silent> <Up>    :call g:GameBlockCommand('arrow')<CR>
nnoremap <buffer> <silent> <Down>  :call g:GameBlockCommand('arrow')<CR>
nnoremap <buffer> <silent> <Left>  :call g:GameBlockCommand('arrow')<CR>
nnoremap <buffer> <silent> <Right> :call g:GameBlockCommand('arrow')<CR>

" Search
nnoremap <buffer> <silent> /       :call g:GameBlockCommand('search')<CR>
nnoremap <buffer> <silent> ?       :call g:GameBlockCommand('search')<CR>
nnoremap <buffer> <silent> n       :call g:GameBlockCommand('search')<CR>
nnoremap <buffer> <silent> N       :call g:GameBlockCommand('search')<CR>
nnoremap <buffer> <silent> *       :call g:GameBlockCommand('search')<CR>
nnoremap <buffer> <silent> #       :call g:GameBlockCommand('search')<CR>

" Find char
nnoremap <buffer> <silent> f       :call g:GameBlockCommand('find')<CR>
nnoremap <buffer> <silent> F       :call g:GameBlockCommand('find')<CR>
nnoremap <buffer> <silent> t       :call g:GameBlockCommand('find')<CR>
nnoremap <buffer> <silent> T       :call g:GameBlockCommand('find')<CR>
nnoremap <buffer> <silent> ;       :call g:GameBlockCommand('find')<CR>
nnoremap <buffer> <silent> ,       :call g:GameBlockCommand('find')<CR>

" Word motion
nnoremap <buffer> <silent> w       :call g:GameBlockCommand('word')<CR>
nnoremap <buffer> <silent> W       :call g:GameBlockCommand('word')<CR>
nnoremap <buffer> <silent> e       :call g:GameBlockCommand('word')<CR>
nnoremap <buffer> <silent> E       :call g:GameBlockCommand('word')<CR>
nnoremap <buffer> <silent> b       :call g:GameBlockCommand('word')<CR>
nnoremap <buffer> <silent> B       :call g:GameBlockCommand('word')<CR>

" Line jump
nnoremap <buffer> <silent> gg      :call g:GameBlockCommand('jump')<CR>
nnoremap <buffer> <silent> G       :call g:GameBlockCommand('jump')<CR>
nnoremap <buffer> <silent> H       :call g:GameBlockCommand('jump')<CR>
nnoremap <buffer> <silent> M       :call g:GameBlockCommand('jump')<CR>
nnoremap <buffer> <silent> L       :call g:GameBlockCommand('jump')<CR>

" Paragraph
nnoremap <buffer> <silent> {       :call g:GameBlockCommand('paragraph')<CR>
nnoremap <buffer> <silent> }       :call g:GameBlockCommand('paragraph')<CR>

" Matching
nnoremap <buffer> <silent> %       :call g:GameBlockCommand('match')<CR>

" Marks
nnoremap <buffer> <silent> '       :call g:GameBlockCommand('mark')<CR>
nnoremap <buffer> <silent> `       :call g:GameBlockCommand('mark')<CR>
nnoremap <buffer> <silent> m       :call g:GameBlockCommand('mark')<CR>

" Jump list
nnoremap <buffer> <silent> <C-O>   :call g:GameBlockCommand('jumplist')<CR>
nnoremap <buffer> <silent> <C-I>   :call g:GameBlockCommand('jumplist')<CR>

" Scrolling
nnoremap <buffer> <silent> <C-D>   :call g:GameBlockCommand('scroll')<CR>
nnoremap <buffer> <silent> <C-U>   :call g:GameBlockCommand('scroll')<CR>
nnoremap <buffer> <silent> <C-F>   :call g:GameBlockCommand('scroll')<CR>
nnoremap <buffer> <silent> <C-B>   :call g:GameBlockCommand('scroll')<CR>

" ============================================================================
" ZZ and ZQ Quit Handling (Vimscript fallback)
" ============================================================================

function! s:GameTryQuit()
  " Check if at exit position
  if line('.') == s:exit_row && col('.') == s:exit_col
    quit!
  endif
  " Silent block if not at exit
endfunction

nnoremap <buffer> <silent> ZZ :call <SID>GameTryQuit()<CR>
nnoremap <buffer> <silent> ZQ :call <SID>GameTryQuit()<CR>
