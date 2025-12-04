" GAMEPLAY Screen for Escape Vim
" Handles active gameplay with maze and sideport

" ============================================================================
" Gameplay State
" ============================================================================

" Track if we're in active gameplay
let s:gameplay_active = 0

" ============================================================================
" Gameplay Lifecycle
" ============================================================================

" Start gameplay for current level
function! Gameplay_Start()
  let s:gameplay_active = 1

  " Initialize game stats
  let g:game_start_time = localtime()
  let g:game_move_count = 0

  " Render sideport in gameplay mode
  let l:meta = g:current_level_meta
  let l:commands = Game_GetAllCommands()
  call Sideport_RenderGameplay(
        \ g:current_level_id,
        \ get(l:meta, 'title', 'Unknown'),
        \ get(l:meta, 'objective', ''),
        \ l:commands,
        \ '00:00',
        \ 0
        \ )

  " Start timer updates
  call Sideport_StartTimer()

  " Load the actual level (maze)
  call Level_Load(g:current_level_path)

  " Set up move tracking
  augroup GameplayMoveTracking
    autocmd!
    autocmd CursorMoved * call s:OnMove()
  augroup END

  " Override quit handling to trigger level completion
  call s:SetupQuitHandling()
endfunction

" Stop gameplay (cleanup)
function! Gameplay_Stop()
  let s:gameplay_active = 0

  " Stop timer
  call Sideport_StopTimer()

  " Remove move tracking
  augroup GameplayMoveTracking
    autocmd!
  augroup END
endfunction

" ============================================================================
" Move Tracking
" ============================================================================

" Called on each cursor movement
function! s:OnMove()
  if s:gameplay_active
    let g:game_move_count += 1
  endif
endfunction

" ============================================================================
" Quit Handling
" ============================================================================

" Set up custom quit handling for level completion/failure
function! s:SetupQuitHandling()
  " Listen for the C-level game events
  " GameLevelComplete: win conditions met
  " GameLevelFailed: win conditions not met
  augroup GameLevelExit
    autocmd!
    autocmd User GameLevelComplete call s:OnLevelComplete()
    autocmd User GameLevelFailed call s:OnLevelFailed()
  augroup END
endfunction

" Called when player quits with win conditions met
function! s:OnLevelComplete()
  call Gameplay_Stop()
  call Game_LevelComplete()
endfunction

" Called when player quits without meeting win conditions
function! s:OnLevelFailed()
  call Gameplay_Stop()
  call Game_LevelFailed()
endfunction

" ============================================================================
" Sideport Update
" ============================================================================

" Update sideport with current stats (called by timer)
function! Gameplay_UpdateSideport()
  if !s:gameplay_active
    return
  endif

  let l:elapsed = localtime() - g:game_start_time
  let l:mins = l:elapsed / 60
  let l:secs = l:elapsed % 60
  let l:time_str = printf('%02d:%02d', l:mins, l:secs)

  let l:meta = g:current_level_meta
  let l:commands = Game_GetAllCommands()
  call Sideport_RenderGameplay(
        \ g:current_level_id,
        \ get(l:meta, 'title', 'Unknown'),
        \ get(l:meta, 'objective', ''),
        \ l:commands,
        \ l:time_str,
        \ g:game_move_count
        \ )
endfunction
