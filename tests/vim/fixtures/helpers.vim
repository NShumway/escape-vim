" Test helpers for Escape Vim VimL tests
" These functions help set up test environments and provide utilities

" Get the directory containing this file
let s:fixtures_dir = expand('<sfile>:p:h')
let s:tests_dir = fnamemodify(s:fixtures_dir, ':h')
let s:repo_root = fnamemodify(s:tests_dir, ':h:h')

" Export paths for use in tests
let g:test_fixtures_dir = s:fixtures_dir
let g:test_repo_root = s:repo_root
let g:test_levels_api_dir = s:repo_root . '/levels/api'

" Source a game module from levels/api/
function! TestHelper_SourceAPI(module) abort
  execute 'source ' . g:test_levels_api_dir . '/' . a:module . '.vim'
endfunction

" Source all API modules in correct order
function! TestHelper_SourceAllAPI() abort
  let l:modules = [
    \ 'util',
    \ 'position',
    \ 'buffer',
    \ 'highlight',
    \ 'input',
    \ 'player',
    \ 'collision',
    \ 'patrol',
    \ 'enemy',
    \ 'level'
    \ ]
  for l:mod in l:modules
    call TestHelper_SourceAPI(l:mod)
  endfor
endfunction

" Load the test maze into current buffer
function! TestHelper_LoadTestMaze() abort
  execute 'edit ' . g:test_fixtures_dir . '/test_maze.txt'
  setlocal nomodifiable
endfunction

" Create a fresh buffer with given lines
function! TestHelper_CreateBuffer(lines) abort
  new
  call setline(1, a:lines)
  setlocal buftype=nofile
  setlocal noswapfile
endfunction

" Clean up test buffer
function! TestHelper_CleanupBuffer() abort
  if exists('g:test_level_meta')
    unlet g:test_level_meta
  endif
  bwipeout!
endfunction

" Load test metadata
function! TestHelper_LoadTestMeta() abort
  let l:meta_file = g:test_fixtures_dir . '/test_meta.vim'
  let l:content = join(readfile(l:meta_file), "\n")
  let g:test_level_meta = eval(l:content)
  return g:test_level_meta
endfunction

" Assert cursor is at expected position
function! TestHelper_AssertCursorAt(line, col) abort
  let l:pos = getcurpos()
  call assert_equal(a:line, l:pos[1], 'Expected line ' . a:line . ' but got ' . l:pos[1])
  call assert_equal(a:col, l:pos[2], 'Expected col ' . a:col . ' but got ' . l:pos[2])
endfunction

" Get character at position (1-indexed line and character column)
function! TestHelper_GetCharAt(line, char_col) abort
  let l:line_text = getline(a:line)
  " Convert character column to byte index for strpart
  let l:byte_idx = byteidx(l:line_text, a:char_col - 1)
  if l:byte_idx < 0
    return ''
  endif
  return nr2char(strgetchar(l:line_text, a:char_col - 1))
endfunction

" Set up a minimal game environment for testing
function! TestHelper_SetupGameEnv() abort
  " Initialize global state variables that the game expects
  let g:level_active = 0
  let g:player_pos = [0, 0]
  let g:game_state = 'test'
endfunction

" Tear down game environment
function! TestHelper_TeardownGameEnv() abort
  if exists('g:level_active')
    unlet g:level_active
  endif
  if exists('g:player_pos')
    unlet g:player_pos
  endif
  if exists('g:game_state')
    unlet g:game_state
  endif
endfunction
