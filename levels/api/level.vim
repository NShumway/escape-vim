" Level API for Escape Vim
" Level loading and lifecycle management

" State
let s:current_meta = {}
let s:exit_pos = [0, 0]  " character coordinates
let s:level_path = ''

" Load a level from a directory path
" @param level_path: path to level directory (e.g., 'levels/level01')
function! Level_Load(level_path)
  call Debug_Log('Level_Load: Starting load of ' . a:level_path)
  let s:level_path = a:level_path

  " 1. Load APIs (order matters - position first, others depend on it)
  source levels/api/util.vim
  source levels/api/position.vim
  source levels/api/buffer.vim
  source levels/api/highlight.vim
  source levels/api/input.vim
  source levels/api/player.vim
  source levels/api/collision.vim
  source levels/api/patrol.vim
  source levels/api/enemy.vim
  call Debug_Log('Level_Load: APIs loaded')

  " 2. Load viewport system
  source levels/viewport.vim

  " 3. Load and parse metadata
  let l:meta_path = a:level_path . '/meta.vim'
  call Debug_Log('Level_Load: Reading meta from ' . l:meta_path)
  try
    let l:meta_content = join(readfile(l:meta_path), "")
    let s:current_meta = eval(l:meta_content)
    call Debug_Log('Level_Load: Meta parsed, title=' . get(s:current_meta, 'title', '?'))
  catch
    call Debug_Error('Level_Load: Failed to parse meta.vim - ' . v:exception)
    throw 'Level_Load: ' . v:exception
  endtry

  " 4. Initialize viewport
  call ViewportInit(s:current_meta)

  " 5. Load the maze file (force reload from disk)
  let l:maze_path = a:level_path . '/maze.txt'
  " Delete any existing buffer for this file to ensure fresh load
  let l:bufnr = bufnr(l:maze_path)
  if l:bufnr != -1
    execute 'bwipeout! ' . l:bufnr
  endif
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

  " 14. Load and spawn spies if spies.vim exists
  let l:spies_path = a:level_path . '/spies.vim'
  if filereadable(l:spies_path)
    call s:LoadSpies(l:spies_path, l:pad_top, l:pad_left)
  endif

  " 15. Set up level features
  let l:features = get(s:current_meta, 'features', [])
  if index(l:features, 'spies') >= 0
    call Collision_SetSpyCallback({-> Game_LevelFailed()})
  endif

  redraw!
endfunction

" Internal: Load spies from spies.vim and spawn them
" @param spies_path: path to spies.vim file
" @param pad_top: viewport top padding
" @param pad_left: viewport left padding
function! s:LoadSpies(spies_path, pad_top, pad_left)
  " Read and evaluate the spies file (it's a Vim list literal)
  let l:lines = readfile(a:spies_path)
  " Filter out comment lines before eval
  let l:code_lines = filter(copy(l:lines), 'v:val !~# "^\\s*\""')
  let l:spies = eval(join(l:code_lines, ''))

  " Spawn each spy with adjusted positions
  for l:spy in l:spies
    " Adjust spawn position for viewport padding
    let l:spawn = [l:spy.spawn[0] + a:pad_top, l:spy.spawn[1] + a:pad_left]

    " Adjust route endpoints for viewport padding
    let l:adjusted_route = []
    for l:vec in l:spy.route
      let l:adjusted_vec = {
            \ 'end': [l:vec.end[0] + a:pad_top, l:vec.end[1] + a:pad_left],
            \ 'dir': l:vec.dir
            \ }
      call add(l:adjusted_route, l:adjusted_vec)
    endfor

    " Spawn the spy
    call Enemy_Spawn(l:spy.id, l:spawn, l:adjusted_route, l:spy.speed)
  endfor

  " Start the enemy tick system
  call Enemy_Start()
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

" Clean up level state (call when leaving gameplay)
function! Level_Cleanup()
  " Only clean up if a level was actually loaded
  if s:level_path == ''
    return
  endif

  " Clear autocommands
  augroup GameLevel
    autocmd!
  augroup END

  " Clean up enemy system (tick unsubscribe handled by state cleanup)
  if exists('*Enemy_RemoveAll')
    call Enemy_RemoveAll()
  endif

  " Clean up API module state (these are defined after Level_Load sources the files)
  if exists('*Highlight_ClearAll')
    call Highlight_ClearAll()
  endif
  if exists('*Player_Cleanup')
    call Player_Cleanup()
  endif
  if exists('*Collision_Cleanup')
    call Collision_Cleanup()
  endif

  " Restore viewport settings
  if exists('*ViewportDisableCenter')
    call ViewportDisableCenter()
  endif

  " Reset level state
  let s:current_meta = {}
  let s:exit_pos = [0, 0]
  let s:level_path = ''
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
