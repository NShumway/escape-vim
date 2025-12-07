" Test suite for levels/api/position.vim
" Uses Vim's built-in assert functions

" Ensure UTF-8 encoding for unicode tests
set encoding=utf-8
scriptencoding utf-8

" Source the module under test
source levels/api/position.vim

let v:errors = []

" ============================================================================
" Test: Pos_CharToBytes
" ============================================================================

function! Test_CharToBytes_ASCII()
  new
  call setline(1, 'hello world')
  call assert_equal(1, Pos_CharToBytes(1, 1))
  call assert_equal(5, Pos_CharToBytes(1, 5))
  call assert_equal(11, Pos_CharToBytes(1, 11))
  bwipeout!
endfunction

function! Test_CharToBytes_Unicode()
  " █ is a 3-byte character
  new
  call setline(1, '████')
  " Character 1 at byte 1
  call assert_equal(1, Pos_CharToBytes(1, 1))
  " Character 2 at byte 4 (after 3 bytes)
  call assert_equal(4, Pos_CharToBytes(1, 2))
  " Character 3 at byte 7 (after 6 bytes)
  call assert_equal(7, Pos_CharToBytes(1, 3))
  bwipeout!
endfunction

function! Test_CharToBytes_Mixed()
  " Mix: "█  █" (wall, 2 spaces, wall)
  new
  call setline(1, '█  █')
  call assert_equal(1, Pos_CharToBytes(1, 1))  " █ at byte 1
  call assert_equal(4, Pos_CharToBytes(1, 2))  " space at byte 4
  call assert_equal(5, Pos_CharToBytes(1, 3))  " space at byte 5
  call assert_equal(6, Pos_CharToBytes(1, 4))  " █ at byte 6
  bwipeout!
endfunction

function! Test_CharToBytes_EdgeCase()
  new
  call setline(1, 'hello')
  " Should return 1 for invalid positions
  call assert_equal(1, Pos_CharToBytes(1, 0))
  call assert_equal(1, Pos_CharToBytes(1, -1))
  bwipeout!
endfunction

" ============================================================================
" Test: Pos_BytesToChar
" ============================================================================

function! Test_BytesToChar_ASCII()
  new
  call setline(1, 'hello world')
  call assert_equal(1, Pos_BytesToChar(1, 1))
  call assert_equal(5, Pos_BytesToChar(1, 5))
  bwipeout!
endfunction

function! Test_BytesToChar_Unicode()
  new
  call setline(1, '████')
  " Byte 4 is the start of char 2
  call assert_equal(2, Pos_BytesToChar(1, 4))
  " Byte 7 is the start of char 3
  call assert_equal(3, Pos_BytesToChar(1, 7))
  bwipeout!
endfunction

function! Test_BytesToChar_EdgeCase()
  new
  call setline(1, 'hello')
  call assert_equal(1, Pos_BytesToChar(1, 0))
  call assert_equal(1, Pos_BytesToChar(1, -1))
  bwipeout!
endfunction

" ============================================================================
" Test: Pos_GetChar
" ============================================================================

function! Test_GetChar_ASCII()
  new
  call setline(1, 'hello')
  call assert_equal('h', Pos_GetChar(1, 1))
  call assert_equal('e', Pos_GetChar(1, 2))
  call assert_equal('o', Pos_GetChar(1, 5))
  bwipeout!
endfunction

function! Test_GetChar_Unicode()
  new
  call setline(1, '████')
  call assert_equal('█', Pos_GetChar(1, 1))
  call assert_equal('█', Pos_GetChar(1, 2))
  bwipeout!
endfunction

function! Test_GetChar_Mixed()
  new
  call setline(1, '█@█')
  call assert_equal('█', Pos_GetChar(1, 1))
  call assert_equal('@', Pos_GetChar(1, 2))
  call assert_equal('█', Pos_GetChar(1, 3))
  bwipeout!
endfunction

" ============================================================================
" Test: Cursor Round-trip
" ============================================================================

function! Test_Cursor_RoundTrip_ASCII()
  new
  call setline(1, 'hello world')
  call Pos_SetCursor(1, 5)
  let pos = Pos_GetCursor()
  call assert_equal([1, 5], pos)
  bwipeout!
endfunction

function! Test_Cursor_RoundTrip_Unicode()
  new
  call setline(1, '████')
  call Pos_SetCursor(1, 3)
  let pos = Pos_GetCursor()
  call assert_equal([1, 3], pos)
  bwipeout!
endfunction

function! Test_Cursor_RoundTrip_MazeLine()
  new
  call setline(1, '██  ██')
  " Set cursor to first space (char 3)
  call Pos_SetCursor(1, 3)
  let pos = Pos_GetCursor()
  call assert_equal([1, 3], pos)
  " Set cursor to second space (char 4)
  call Pos_SetCursor(1, 4)
  let pos = Pos_GetCursor()
  call assert_equal([1, 4], pos)
  bwipeout!
endfunction

" ============================================================================
" Test: Pos_GetCursorBytes
" ============================================================================

function! Test_GetCursorBytes()
  new
  call setline(1, '████')
  " Set cursor to character 2 (which is byte 4)
  call Pos_SetCursor(1, 2)
  let pos = Pos_GetCursorBytes()
  call assert_equal(1, pos[0])
  call assert_equal(4, pos[1])
  bwipeout!
endfunction

" ============================================================================
" Run all tests
" ============================================================================

function! RunAllTests()
  let l:tests = [
    \ 'Test_CharToBytes_ASCII',
    \ 'Test_CharToBytes_Unicode',
    \ 'Test_CharToBytes_Mixed',
    \ 'Test_CharToBytes_EdgeCase',
    \ 'Test_BytesToChar_ASCII',
    \ 'Test_BytesToChar_Unicode',
    \ 'Test_BytesToChar_EdgeCase',
    \ 'Test_GetChar_ASCII',
    \ 'Test_GetChar_Unicode',
    \ 'Test_GetChar_Mixed',
    \ 'Test_Cursor_RoundTrip_ASCII',
    \ 'Test_Cursor_RoundTrip_Unicode',
    \ 'Test_Cursor_RoundTrip_MazeLine',
    \ 'Test_GetCursorBytes',
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
