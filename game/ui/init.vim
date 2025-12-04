" Escape Vim - Main UI Initialization
" Launch with: ./src/vim --clean -S game/ui/init.vim

" ============================================================================
" Viewport resize control (we manage our own layout)
" ============================================================================

let s:viewport_disable_resize = 1

function! UI_IsResizeDisabled()
  return s:viewport_disable_resize
endfunction

" ============================================================================
" Load Level API (needed for gameplay)
" ============================================================================

source levels/api/util.vim
source levels/api/level.vim

" ============================================================================
" Load UI Components
" ============================================================================

" Load save system first (no dependencies)
source game/ui/save.vim

" Load keybind utilities (needed by all UI screens)
source game/ui/keybinds.vim

" Load sideport (needed by lore, gameplay, results)
source game/ui/sideport.vim

" Load screen modules
source game/ui/lore.vim
source game/ui/gameplay.vim
source game/ui/fireworks.vim
source game/ui/defeat.vim
source game/ui/results.vim

" Load state machine last (orchestrates everything)
source game/ui/state.vim

" ============================================================================
" UI Configuration
" ============================================================================

function! s:SetupUI()
  " Clean UI - no statusline, no ruler, etc.
  set laststatus=0
  set noshowcmd
  set noshowmode
  set shortmess+=F
  set noruler
  set cmdheight=1
  set mouse=

  " No line numbers
  set nonumber
  set norelativenumber

  " No cursor line highlighting
  set nocursorline
  set nocursorcolumn

  " Hide terminal cursor
  set t_ve=

  " Prevent accidental modifications
  set nomodifiable

  " Terminal settings
  set t_Co=256
  set background=dark
endfunction

" ============================================================================
" Launch Game
" ============================================================================

call s:SetupUI()
call Game_Start()
