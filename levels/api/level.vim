" Level API for Escape Vim
" Level loading and lifecycle management

" State
let s:current_meta = {}
let s:exit_pos = [0, 0]  " character coordinates
let s:level_path = ''

" Load a level from a directory path
" @param level_path: path to level directory (e.g., 'levels/level01')
function! Level_Load(level_path)
  let s:level_path = a:level_path

  " 1. Load APIs (order matters - position first, others depend on it)
  source levels/api/position.vim
  source levels/api/buffer.vim
  source levels/api/highlight.vim
  source levels/api/input.vim
  source levels/api/player.vim
  source levels/api/collision.vim

  " 2. Load viewport system
  source levels/viewport.vim

  " 3. Load and parse metadata
  let l:meta_path = a:level_path . '/meta.vim'
  let s:current_meta = eval(join(readfile(l:meta_path), ''))

  " 4. Initialize viewport
  call ViewportInit(s:current_meta)

  " 5. Load the maze file
  let l:maze_path = a:level_path . '/maze.txt'
  execute 'edit ' . l:maze_path
  setlocal buftype=nofile
  setlocal noswapfile

  " 6. Apply viewport padding
  let l:padding = ViewportPadBuffer()
  let l:pad_top = l:padding[0]
  let l:pad_left = l:padding[1]

  " 7. Calculate adjusted positions
  let l:start = get(s:current_meta, 'start_cursor', [2, 2])
  let l:start_line = l:start[0] + l:pad_top
  let l:start_col = l:start[1] + l:pad_left

  let l:exit = get(s:current_meta, 'exit_cursor', [2, 45])
  let s:exit_pos = [l:exit[0] + l:pad_top, l:exit[1] + l:pad_left]

  " 8. Set C-level exit position (needs byte position)
  let l:exit_byte = Pos_CharToBytes(s:exit_pos[0], s:exit_pos[1])
  call gamesetexit(s:exit_pos[0], l:exit_byte)

  " 9. Initialize player and collision tracking
  call Player_Init(l:start_line, l:start_col)
  call Collision_SetLastValidPos(l:start_line, l:start_col)

  " 10. Set up input blocking based on level config
  let l:blocked = get(s:current_meta, 'blocked_categories',
        \ ['arrows', 'search', 'find_char', 'word_motion', 'line_jump',
        \  'paragraph', 'matching', 'marks', 'jump_list', 'scroll'])
  call Input_BlockCategories(l:blocked)

  " 11. Set up collision handling autocommand
  augroup GameLevel
    autocmd!
    autocmd CursorMoved <buffer> call s:OnCursorMoved()
    " Clear command line after any command (helps hide blocked :q)
    autocmd CmdlineLeave <buffer> redraw!
  augroup END

  " 12. Set up ZZ/ZQ quit handling
  nnoremap <buffer> <silent> ZZ :call <SID>GameTryQuit()<CR>
  nnoremap <buffer> <silent> ZQ :call <SID>GameTryQuit()<CR>

  " 13. Lock buffer and set UI options
  setlocal nomodifiable
  call s:SetupUI()

  " 14. Load level-specific logic if present
  let l:logic_path = a:level_path . '/logic.vim'
  if filereadable(l:logic_path)
    execute 'source ' . l:logic_path
  endif

  redraw!
endfunction

" Internal: Handle cursor movement
function! s:OnCursorMoved()
  let l:result = Collision_OnMove()
  if !l:result.blocked
    call Player_MoveTo(l:result.pos[0], l:result.pos[1])
  endif
endfunction

" Internal: Try to quit (only works at exit position)
function! s:GameTryQuit()
  if Level_AtExit()
    quit!
  endif
  " Silent block if not at exit
endfunction

" Internal: Set up clean UI
function! s:SetupUI()
  set laststatus=0
  set noshowcmd
  set noshowmode
  set shortmess+=F
  set noruler
  set cmdheight=1
  set mouse=

  " Hide the terminal cursor - let PlayerChar highlight be the visual indicator
  " This makes the @ appear with proper white-on-black highlighting
  set t_ve=
endfunction

" Get the current level's metadata
" @return: metadata dictionary
function! Level_GetMeta()
  return copy(s:current_meta)
endfunction

" Check if player is at the exit position
" @return: 1 if at exit, 0 otherwise
function! Level_AtExit()
  let l:pos = Player_GetPos()
  return l:pos[0] == s:exit_pos[0] && l:pos[1] == s:exit_pos[1]
endfunction

" Attempt to quit the level (only succeeds if at exit)
" @return: 1 if quit succeeded, 0 if blocked
function! Level_TryQuit()
  if Level_AtExit()
    quit!
    return 1
  endif
  return 0
endfunction
