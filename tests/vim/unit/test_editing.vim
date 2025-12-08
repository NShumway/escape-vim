" Test suite for levels/api/editing.vim
" Tests editing level match checking and edit commands

" Ensure UTF-8 encoding for unicode tests
set encoding=utf-8
scriptencoding utf-8

" Source required modules in dependency order
source levels/api/position.vim
source levels/api/buffer.vim
source levels/api/highlight.vim
source levels/api/editing.vim

let v:errors = []

" Helper to create a test editing document
function! s:CreateTestDocument()
  new
  call setline(1, 'Target:  Hello World')
  call setline(2, '─────────────────────')
  call setline(3, '         Hello Wrold*')
  setlocal buftype=nofile
  setlocal noswapfile
  setlocal nomodifiable
endfunction

" Helper to initialize editing with test document
function! s:InitTestEditing()
  call s:CreateTestDocument()
  let l:meta = {
    \ 'target_text': 'Hello World',
    \ 'editable_region': {
    \   'start_line': 3,
    \   'end_line': 3,
    \   'start_col': 10,
    \   'end_col': 20,
    \ },
    \ 'divider_line': 2,
    \ 'exit_cursor': [3, 21],
    \ }
  call Editing_Init(l:meta)
endfunction

" ============================================================================
" Test: Editing_CheckMatch
" ============================================================================

function! Test_CheckMatch_NoMatch()
  call s:InitTestEditing()

  " Document has 'Hello Wrold' but target is 'Hello World'
  let result = Editing_CheckMatch()
  call assert_equal(0, result, 'Mismatched text should not match')

  call Editing_Cleanup()
  bwipeout!
endfunction

function! Test_CheckMatch_Match()
  call s:CreateTestDocument()

  " Set up with matching text
  setlocal modifiable
  call setline(3, '         Hello World*')
  setlocal nomodifiable

  let l:meta = {
    \ 'target_text': 'Hello World',
    \ 'editable_region': {
    \   'start_line': 3,
    \   'end_line': 3,
    \   'start_col': 10,
    \   'end_col': 20,
    \ },
    \ 'divider_line': 2,
    \ 'exit_cursor': [3, 21],
    \ }
  call Editing_Init(l:meta)

  let result = Editing_CheckMatch()
  call assert_equal(1, result, 'Matching text should match')

  call Editing_Cleanup()
  bwipeout!
endfunction

" ============================================================================
" Test: Editing_InRegion
" ============================================================================

function! Test_InRegion_Inside()
  call s:InitTestEditing()

  " Position inside editable region
  call assert_equal(1, Editing_InRegion(3, 10), 'Start of region should be in')
  call assert_equal(1, Editing_InRegion(3, 15), 'Middle of region should be in')
  call assert_equal(1, Editing_InRegion(3, 20), 'End of region should be in')

  call Editing_Cleanup()
  bwipeout!
endfunction

function! Test_InRegion_Outside()
  call s:InitTestEditing()

  " Position outside editable region
  call assert_equal(0, Editing_InRegion(1, 10), 'Target line should be out')
  call assert_equal(0, Editing_InRegion(2, 10), 'Divider line should be out')
  call assert_equal(0, Editing_InRegion(3, 9), 'Before region start should be out')
  call assert_equal(0, Editing_InRegion(3, 21), 'Exit tile should be out')

  call Editing_Cleanup()
  bwipeout!
endfunction

" ============================================================================
" Test: Editing_IsExitTile
" ============================================================================

function! Test_IsExitTile()
  call s:InitTestEditing()

  call assert_equal(1, Editing_IsExitTile(3, 21), 'Exit position should be exit tile')
  call assert_equal(0, Editing_IsExitTile(3, 20), 'Non-exit position should not be exit')
  call assert_equal(0, Editing_IsExitTile(1, 21), 'Wrong line should not be exit')

  call Editing_Cleanup()
  bwipeout!
endfunction

" ============================================================================
" Test: Editing_DeleteChar
" ============================================================================

function! Test_DeleteChar_InRegion()
  call s:InitTestEditing()

  " Position cursor in editable region
  call Pos_SetCursor(3, 15)

  " Delete character
  call Editing_DeleteChar()

  " Character should be replaced with space
  let char = Pos_GetChar(3, 15)
  call assert_equal(' ', char, 'Deleted char should become space')

  call Editing_Cleanup()
  bwipeout!
endfunction

function! Test_DeleteChar_OutsideRegion()
  call s:InitTestEditing()

  " Position cursor outside editable region (target line)
  call Pos_SetCursor(1, 10)

  " Get char before
  let before = Pos_GetChar(1, 10)

  " Try to delete (should fail silently)
  call Editing_DeleteChar()

  " Character should be unchanged
  let after = Pos_GetChar(1, 10)
  call assert_equal(before, after, 'Char outside region should not change')

  call Editing_Cleanup()
  bwipeout!
endfunction

" ============================================================================
" Test: Editing_DeleteWord
" ============================================================================

function! Test_DeleteWord_InRegion()
  call s:CreateTestDocument()

  " Set up document with a word to delete
  setlocal modifiable
  call setline(3, '         Hello Wrold*')
  setlocal nomodifiable

  let l:meta = {
    \ 'target_text': 'Hello World',
    \ 'editable_region': {
    \   'start_line': 3,
    \   'end_line': 3,
    \   'start_col': 10,
    \   'end_col': 20,
    \ },
    \ 'divider_line': 2,
    \ 'exit_cursor': [3, 21],
    \ }
  call Editing_Init(l:meta)

  " Position cursor at start of 'Wrold'
  call Pos_SetCursor(3, 16)

  " Delete word
  call Editing_DeleteWord()

  " Word should be replaced with spaces
  let line = getline(3)
  " 'Wrold' (5 chars) should become spaces
  call assert_match('Hello      ', line, 'Word should be deleted (spaces)')

  call Editing_Cleanup()
  bwipeout!
endfunction

" ============================================================================
" Test: Multi-line editing
" ============================================================================

function! Test_MultiLine_Match()
  new
  call setline(1, 'Target:  Line one')
  call setline(2, '         Line two')
  call setline(3, '──────────────────')
  call setline(4, '         Line one')
  call setline(5, '         Line two*')
  setlocal buftype=nofile
  setlocal noswapfile
  setlocal nomodifiable

  let l:meta = {
    \ 'target_text': "Line one\nLine two",
    \ 'editable_region': {
    \   'start_line': 4,
    \   'end_line': 5,
    \   'start_col': 10,
    \   'end_col': 17,
    \ },
    \ 'divider_line': 3,
    \ 'exit_cursor': [5, 18],
    \ }
  call Editing_Init(l:meta)

  let result = Editing_CheckMatch()
  call assert_equal(1, result, 'Multi-line match should work')

  call Editing_Cleanup()
  bwipeout!
endfunction

" ============================================================================
" Run all tests
" ============================================================================

function! RunAllTests()
  let l:tests = [
    \ 'Test_CheckMatch_NoMatch',
    \ 'Test_CheckMatch_Match',
    \ 'Test_InRegion_Inside',
    \ 'Test_InRegion_Outside',
    \ 'Test_IsExitTile',
    \ 'Test_DeleteChar_InRegion',
    \ 'Test_DeleteChar_OutsideRegion',
    \ 'Test_DeleteWord_InRegion',
    \ 'Test_MultiLine_Match',
    \ ]

  let l:passed = 0
  let l:failed = 0

  for l:test in l:tests
    let v:errors = []
    try
      execute 'call ' . l:test . '()'
      if len(v:errors) == 0
        echo 'PASS: ' . l:test
        let l:passed += 1
      else
        echo 'FAIL: ' . l:test
        for l:err in v:errors
          echo '  ' . l:err
        endfor
        let l:failed += 1
      endif
    catch
      echo 'ERROR: ' . l:test . ' - ' . v:exception
      let l:failed += 1
    endtry
  endfor

  echo ''
  echo '================================'
  echo 'Results: ' . l:passed . ' passed, ' . l:failed . ' failed'
  echo '================================'

  if l:failed > 0
    cquit!
  else
    qall!
  endif
endfunction

call RunAllTests()
