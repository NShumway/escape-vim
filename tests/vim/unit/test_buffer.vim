" Test suite for levels/api/buffer.vim
" Tests buffer manipulation with character coordinates

" Ensure UTF-8 encoding for unicode tests
set encoding=utf-8
scriptencoding utf-8

" Source required modules in dependency order
source levels/api/position.vim
source levels/api/buffer.vim

let v:errors = []

" Helper to create a test buffer
function! s:CreateTestBuffer()
  new
  call setline(1, '██████')
  call setline(2, '█    █')
  call setline(3, '█    █')
  call setline(4, '██████')
  setlocal buftype=nofile
  setlocal noswapfile
endfunction

" ============================================================================
" Test: Buffer_GetChar
" ============================================================================

function! Test_GetChar_WallChar()
  call s:CreateTestBuffer()
  call assert_equal('█', Buffer_GetChar(1, 1), 'Should get wall at (1,1)')
  call assert_equal('█', Buffer_GetChar(1, 6), 'Should get wall at (1,6)')
  bwipeout!
endfunction

function! Test_GetChar_SpaceChar()
  call s:CreateTestBuffer()
  call assert_equal(' ', Buffer_GetChar(2, 2), 'Should get space at (2,2)')
  call assert_equal(' ', Buffer_GetChar(2, 5), 'Should get space at (2,5)')
  bwipeout!
endfunction

function! Test_GetChar_AllLine2()
  call s:CreateTestBuffer()
  " Check all characters on line 2: █, space, space, space, space, █
  call assert_equal('█', Buffer_GetChar(2, 1))
  call assert_equal(' ', Buffer_GetChar(2, 2))
  call assert_equal(' ', Buffer_GetChar(2, 3))
  call assert_equal(' ', Buffer_GetChar(2, 4))
  call assert_equal(' ', Buffer_GetChar(2, 5))
  call assert_equal('█', Buffer_GetChar(2, 6))
  bwipeout!
endfunction

function! Test_GetChar_DifferentLines()
  call s:CreateTestBuffer()
  " First char of each line
  call assert_equal('█', Buffer_GetChar(1, 1))
  call assert_equal('█', Buffer_GetChar(2, 1))
  call assert_equal('█', Buffer_GetChar(3, 1))
  call assert_equal('█', Buffer_GetChar(4, 1))
  bwipeout!
endfunction

" ============================================================================
" Test: Buffer_SetChar
" ============================================================================

function! Test_SetChar_PlacePlayer()
  call s:CreateTestBuffer()
  call Buffer_SetChar(2, 2, '@')
  call assert_equal('@', Buffer_GetChar(2, 2), 'Should place @ at (2,2)')
  bwipeout!
endfunction

function! Test_SetChar_NoAffectNeighbors()
  call s:CreateTestBuffer()
  call Buffer_SetChar(2, 3, '@')
  " Check neighbors are unchanged
  call assert_equal(' ', Buffer_GetChar(2, 2), 'Left neighbor unchanged')
  call assert_equal('@', Buffer_GetChar(2, 3), 'Target changed')
  call assert_equal(' ', Buffer_GetChar(2, 4), 'Right neighbor unchanged')
  bwipeout!
endfunction

function! Test_SetChar_ReplaceWithSpace()
  call s:CreateTestBuffer()
  call Buffer_SetChar(2, 2, '@')
  call assert_equal('@', Buffer_GetChar(2, 2))
  call Buffer_SetChar(2, 2, ' ')
  call assert_equal(' ', Buffer_GetChar(2, 2), 'Should replace @ with space')
  bwipeout!
endfunction

function! Test_SetChar_UnicodeChar()
  call s:CreateTestBuffer()
  call Buffer_SetChar(2, 2, '★')
  call assert_equal('★', Buffer_GetChar(2, 2), 'Should place unicode char')
  bwipeout!
endfunction

function! Test_SetChar_LineLengthPreserved()
  call s:CreateTestBuffer()
  " Get original line length
  let original_len = strchars(getline(2))

  " Set a character
  call Buffer_SetChar(2, 3, '@')

  " Line length should be the same
  let new_len = strchars(getline(2))
  call assert_equal(original_len, new_len, 'Line length should be preserved')
  bwipeout!
endfunction

function! Test_SetChar_MultipleReplacements()
  call s:CreateTestBuffer()
  call Buffer_SetChar(2, 2, 'A')
  call Buffer_SetChar(2, 3, 'B')
  call Buffer_SetChar(2, 4, 'C')
  call Buffer_SetChar(2, 5, 'D')

  call assert_equal('A', Buffer_GetChar(2, 2))
  call assert_equal('B', Buffer_GetChar(2, 3))
  call assert_equal('C', Buffer_GetChar(2, 4))
  call assert_equal('D', Buffer_GetChar(2, 5))
  bwipeout!
endfunction

function! Test_SetChar_FirstChar()
  call s:CreateTestBuffer()
  call Buffer_SetChar(2, 1, 'X')
  call assert_equal('X', Buffer_GetChar(2, 1), 'Should replace first char')
  bwipeout!
endfunction

function! Test_SetChar_LastChar()
  call s:CreateTestBuffer()
  call Buffer_SetChar(2, 6, 'X')
  call assert_equal('X', Buffer_GetChar(2, 6), 'Should replace last char')
  bwipeout!
endfunction

" ============================================================================
" Test: Buffer_ReplaceRange
" ============================================================================

function! Test_ReplaceRange_SingleChar()
  call s:CreateTestBuffer()
  call Buffer_ReplaceRange(2, 2, 2, '@')
  call assert_equal('@', Buffer_GetChar(2, 2))
  bwipeout!
endfunction

function! Test_ReplaceRange_MultipleChars()
  call s:CreateTestBuffer()
  " Replace chars 2-4 with "ABC"
  call Buffer_ReplaceRange(2, 2, 4, 'ABC')
  call assert_equal('A', Buffer_GetChar(2, 2))
  call assert_equal('B', Buffer_GetChar(2, 3))
  call assert_equal('C', Buffer_GetChar(2, 4))
  bwipeout!
endfunction

function! Test_ReplaceRange_ShorterString()
  call s:CreateTestBuffer()
  " Original: █    █ (6 chars)
  " Replace chars 2-5 (4 spaces) with "X" (1 char)
  call Buffer_ReplaceRange(2, 2, 5, 'X')
  " Line becomes: █X█ (3 chars)
  let line = getline(2)
  call assert_equal(3, strchars(line), 'Line should be shorter')
  bwipeout!
endfunction

function! Test_ReplaceRange_LongerString()
  call s:CreateTestBuffer()
  " Original line 3: █    █ (6 chars)
  " Replace chars 2-3 with "ABCD" (4 chars)
  call Buffer_ReplaceRange(3, 2, 3, 'ABCD')
  call assert_equal('A', Buffer_GetChar(3, 2))
  call assert_equal('B', Buffer_GetChar(3, 3))
  call assert_equal('C', Buffer_GetChar(3, 4))
  call assert_equal('D', Buffer_GetChar(3, 5))
  bwipeout!
endfunction

" ============================================================================
" Test: Buffer_WithModifiable
" ============================================================================

function! Test_WithModifiable_ExecutesCallback()
  call s:CreateTestBuffer()
  let g:test_executed = 0

  function! TestCallback()
    let g:test_executed = 1
    call setline(2, '█test█')
  endfunction

  call Buffer_WithModifiable(function('TestCallback'))

  call assert_equal(1, g:test_executed, 'Callback should execute')
  call assert_equal('█test█', getline(2), 'Buffer should be modified')

  unlet g:test_executed
  delfunction TestCallback
  bwipeout!
endfunction

function! Test_WithModifiable_RestoresNonModifiable()
  call s:CreateTestBuffer()
  setlocal nomodifiable

  function! TestNoop()
    " Do nothing
  endfunction

  call Buffer_WithModifiable(function('TestNoop'))

  " Should be non-modifiable after
  call assert_equal(0, &modifiable, 'Buffer should be non-modifiable after')

  delfunction TestNoop
  bwipeout!
endfunction

" ============================================================================
" Test: Edge cases
" ============================================================================

function! Test_EdgeCase_UnicodeInASCII()
  new
  call setline(1, 'abcdef')
  setlocal buftype=nofile

  " Replace middle char with unicode
  call Buffer_SetChar(1, 3, '★')

  call assert_equal('a', Buffer_GetChar(1, 1))
  call assert_equal('b', Buffer_GetChar(1, 2))
  call assert_equal('★', Buffer_GetChar(1, 3))
  call assert_equal('d', Buffer_GetChar(1, 4))

  bwipeout!
endfunction

" ============================================================================
" Run all tests
" ============================================================================

function! RunAllTests()
  let l:tests = [
    \ 'Test_GetChar_WallChar',
    \ 'Test_GetChar_SpaceChar',
    \ 'Test_GetChar_AllLine2',
    \ 'Test_GetChar_DifferentLines',
    \ 'Test_SetChar_PlacePlayer',
    \ 'Test_SetChar_NoAffectNeighbors',
    \ 'Test_SetChar_ReplaceWithSpace',
    \ 'Test_SetChar_UnicodeChar',
    \ 'Test_SetChar_LineLengthPreserved',
    \ 'Test_SetChar_MultipleReplacements',
    \ 'Test_SetChar_FirstChar',
    \ 'Test_SetChar_LastChar',
    \ 'Test_ReplaceRange_SingleChar',
    \ 'Test_ReplaceRange_MultipleChars',
    \ 'Test_ReplaceRange_ShorterString',
    \ 'Test_ReplaceRange_LongerString',
    \ 'Test_WithModifiable_ExecutesCallback',
    \ 'Test_WithModifiable_RestoresNonModifiable',
    \ 'Test_EdgeCase_UnicodeInASCII',
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
