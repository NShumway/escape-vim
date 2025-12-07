" Test suite for levels/api/collision.vim
" Tests wall detection and collision response

" Ensure UTF-8 encoding for unicode tests
set encoding=utf-8
scriptencoding utf-8

" Source required modules in dependency order
source levels/api/position.vim
source levels/api/highlight.vim
source levels/api/collision.vim

let v:errors = []

" Helper to create a test maze
function! s:CreateTestMaze()
  new
  call setline(1, '██████')
  call setline(2, '█    █')
  call setline(3, '█ ██ █')
  call setline(4, '█    █')
  call setline(5, '██████')
  setlocal buftype=nofile
  setlocal noswapfile
endfunction

" ============================================================================
" Test: Collision_IsWall
" ============================================================================

function! Test_IsWall_Corners()
  call s:CreateTestMaze()
  call assert_equal(1, Collision_IsWall(1, 1), 'Top-left corner should be wall')
  call assert_equal(1, Collision_IsWall(1, 6), 'Top-right corner should be wall')
  call assert_equal(1, Collision_IsWall(5, 1), 'Bottom-left corner should be wall')
  call assert_equal(1, Collision_IsWall(5, 6), 'Bottom-right corner should be wall')
  call Collision_Cleanup()
  bwipeout!
endfunction

function! Test_IsWall_Edges()
  call s:CreateTestMaze()
  call assert_equal(1, Collision_IsWall(1, 3), 'Top edge should be wall')
  call assert_equal(1, Collision_IsWall(5, 4), 'Bottom edge should be wall')
  call assert_equal(1, Collision_IsWall(3, 1), 'Left edge should be wall')
  call assert_equal(1, Collision_IsWall(3, 6), 'Right edge should be wall')
  call Collision_Cleanup()
  bwipeout!
endfunction

function! Test_IsWall_InteriorWall()
  call s:CreateTestMaze()
  " There's an interior wall at line 3, chars 3-4
  call assert_equal(1, Collision_IsWall(3, 3), 'Interior wall position 1')
  call assert_equal(1, Collision_IsWall(3, 4), 'Interior wall position 2')
  call Collision_Cleanup()
  bwipeout!
endfunction

function! Test_IsWall_OpenSpace()
  call s:CreateTestMaze()
  " Line 2 has open spaces at chars 2-5
  call assert_equal(0, Collision_IsWall(2, 2), 'Open space at (2,2)')
  call assert_equal(0, Collision_IsWall(2, 3), 'Open space at (2,3)')
  call assert_equal(0, Collision_IsWall(2, 4), 'Open space at (2,4)')
  call assert_equal(0, Collision_IsWall(2, 5), 'Open space at (2,5)')
  call Collision_Cleanup()
  bwipeout!
endfunction

function! Test_IsWall_AroundInteriorWall()
  call s:CreateTestMaze()
  " Line 3, char 2 and 5 are open (around the interior wall)
  call assert_equal(0, Collision_IsWall(3, 2), 'Open space before interior wall')
  call assert_equal(0, Collision_IsWall(3, 5), 'Open space after interior wall')
  call Collision_Cleanup()
  bwipeout!
endfunction

" ============================================================================
" Test: Collision_SetWallChar
" ============================================================================

function! Test_SetWallChar_Custom()
  call s:CreateTestMaze()

  " Change wall character to '#'
  call Collision_SetWallChar('#')

  " Original walls should no longer be detected
  call assert_equal(0, Collision_IsWall(1, 1), 'Original wall not detected with new char')

  " Create a line with '#' walls
  call setline(1, '######')
  call assert_equal(1, Collision_IsWall(1, 1), 'New wall char detected')

  " Reset back to default
  call Collision_SetWallChar('█')
  call Collision_Cleanup()
  bwipeout!
endfunction

" ============================================================================
" Test: Collision_OnMove
" ============================================================================

function! Test_OnMove_ValidMove()
  call s:CreateTestMaze()

  " Start at a valid position
  call Collision_SetLastValidPos(2, 2)
  call Pos_SetCursor(2, 3)

  let result = Collision_OnMove()

  call assert_equal(0, result.blocked, 'Valid move should not be blocked')
  call assert_equal([2, 3], result.pos, 'Position should be new position')

  call Collision_Cleanup()
  bwipeout!
endfunction

function! Test_OnMove_WallBlocks()
  call s:CreateTestMaze()

  " Set valid position first
  call Collision_SetLastValidPos(2, 2)

  " Move cursor to a wall position
  call Pos_SetCursor(1, 1)

  let result = Collision_OnMove()

  call assert_equal(1, result.blocked, 'Wall move should be blocked')
  call assert_equal([2, 2], result.pos, 'Should return last valid position')

  call Collision_Cleanup()
  bwipeout!
endfunction

function! Test_OnMove_CursorBounces()
  call s:CreateTestMaze()

  " Set valid position
  call Collision_SetLastValidPos(2, 2)

  " Try to move into wall
  call Pos_SetCursor(1, 2)
  call Collision_OnMove()

  " Cursor should be back at last valid position
  let pos = Pos_GetCursor()
  call assert_equal([2, 2], pos, 'Cursor should bounce back')

  call Collision_Cleanup()
  bwipeout!
endfunction

function! Test_OnMove_SequentialMoves()
  call s:CreateTestMaze()
  call Collision_SetLastValidPos(2, 2)

  " Move to (2, 3)
  call Pos_SetCursor(2, 3)
  let result1 = Collision_OnMove()
  call assert_equal(0, result1.blocked, 'First move should succeed')

  " Move to (2, 4)
  call Pos_SetCursor(2, 4)
  let result2 = Collision_OnMove()
  call assert_equal(0, result2.blocked, 'Second move should succeed')

  " Now try to hit a wall
  call Pos_SetCursor(1, 4)
  let result3 = Collision_OnMove()

  " Should bounce back to last valid (2, 4)
  call assert_equal(1, result3.blocked, 'Wall hit should be blocked')
  call assert_equal([2, 4], result3.pos, 'Should return last valid position')

  call Collision_Cleanup()
  bwipeout!
endfunction

function! Test_OnMove_InteriorWall()
  call s:CreateTestMaze()
  call Collision_SetLastValidPos(3, 2)

  " Try to move into interior wall at (3, 3)
  call Pos_SetCursor(3, 3)
  let result = Collision_OnMove()

  call assert_equal(1, result.blocked, 'Interior wall should block')
  call assert_equal([3, 2], result.pos, 'Should return last valid position')

  call Collision_Cleanup()
  bwipeout!
endfunction

" ============================================================================
" Test: Collision_SetWallCallback
" ============================================================================

function! Test_WallCallback_Called()
  call s:CreateTestMaze()

  let g:test_callback_called = 0
  let g:test_callback_line = 0
  let g:test_callback_col = 0

  function! TestWallCallback(line, col)
    let g:test_callback_called = 1
    let g:test_callback_line = a:line
    let g:test_callback_col = a:col
  endfunction

  call Collision_SetWallCallback(function('TestWallCallback'))
  call Collision_SetLastValidPos(2, 2)

  " Move into a wall
  call Pos_SetCursor(1, 2)
  call Collision_OnMove()

  " Callback should have been called with wall position
  call assert_equal(1, g:test_callback_called, 'Callback should be called')
  call assert_equal(1, g:test_callback_line, 'Callback should receive wall line')
  call assert_equal(2, g:test_callback_col, 'Callback should receive wall col')

  " Cleanup
  unlet g:test_callback_called
  unlet g:test_callback_line
  unlet g:test_callback_col
  delfunction TestWallCallback
  call Collision_Cleanup()
  bwipeout!
endfunction

" ============================================================================
" Test: Collision_Cleanup
" ============================================================================

function! Test_Cleanup_Resets()
  call s:CreateTestMaze()

  " Set some state
  call Collision_SetLastValidPos(3, 3)
  call Collision_SetWallCallback({line, col -> 0})

  " Clean up
  call Collision_Cleanup()

  " After cleanup, module should be in clean state
  " (we can't easily verify internal state, but it shouldn't crash)
  bwipeout!
endfunction

" ============================================================================
" Run all tests
" ============================================================================

function! RunAllTests()
  let l:tests = [
    \ 'Test_IsWall_Corners',
    \ 'Test_IsWall_Edges',
    \ 'Test_IsWall_InteriorWall',
    \ 'Test_IsWall_OpenSpace',
    \ 'Test_IsWall_AroundInteriorWall',
    \ 'Test_SetWallChar_Custom',
    \ 'Test_OnMove_ValidMove',
    \ 'Test_OnMove_WallBlocks',
    \ 'Test_OnMove_CursorBounces',
    \ 'Test_OnMove_SequentialMoves',
    \ 'Test_OnMove_InteriorWall',
    \ 'Test_WallCallback_Called',
    \ 'Test_Cleanup_Resets',
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
