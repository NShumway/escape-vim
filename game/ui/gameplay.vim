" GAMEPLAY Screen for Escape Vim
" Handles active gameplay with maze and sideport

" ============================================================================
" Gameplay State
" ============================================================================

" Track if we're in active gameplay
let s:gameplay_active = 0

" Game statistics (owned by this module)
let s:start_time = 0
let s:move_count = 0
let s:final_time = 0
let s:final_moves = 0

" ============================================================================
" Stats Getters
" ============================================================================

" Get elapsed time since gameplay started
function! Gameplay_GetElapsed()
  return localtime() - s:start_time
endfunction

" Get current move count
function! Gameplay_GetMoves()
  return s:move_count
endfunction

" Get final stats (frozen at level completion)
function! Gameplay_GetFinalStats()
  return {'time': s:final_time, 'moves': s:final_moves}
endfunction

" Freeze final stats at level completion
function! Gameplay_FreezeFinalStats()
  let s:final_time = localtime() - s:start_time
  let s:final_moves = s:move_count
endfunction

" ============================================================================
" Gameplay Lifecycle
" ============================================================================

" Start gameplay for current level
function! Gameplay_Start()
  let s:gameplay_active = 1

  " Initialize game stats
  let s:start_time = localtime()
  let s:move_count = 0

  " Render sideport in gameplay mode
  let l:meta = Game_GetLevelMeta()
  let l:commands = Game_GetAllCommands()
  call Sideport_RenderGameplay(
        \ Game_GetLevelId(),
        \ get(l:meta, 'title', 'Unknown'),
        \ get(l:meta, 'objective', ''),
        \ l:commands,
        \ '00:00',
        \ 0
        \ )

  " Start timer updates
  call Sideport_StartTimer()

  " Load the actual level (maze)
  call Level_Load(Game_GetLevelPath())

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

  " Clean up level state (highlights, player, collision, viewport)
  call Level_Cleanup()
endfunction

" ============================================================================
" Move Tracking
" ============================================================================

" Called on each cursor movement
function! s:OnMove()
  if s:gameplay_active
    let s:move_count += 1
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

  let l:elapsed = Gameplay_GetElapsed()
  let l:mins = l:elapsed / 60
  let l:secs = l:elapsed % 60
  let l:time_str = printf('%02d:%02d', l:mins, l:secs)

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
endfunction
