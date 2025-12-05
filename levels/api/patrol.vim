" Patrol System for Escape Vim
" Route/vector logic for spy movement

" ============================================================================
" Vector Format
" ============================================================================
"
" A vector defines movement from current position to end position:
" {
"   'end': [10, 15],    " target [line, char_col]
"   'dir': 'right'      " direction: 'up', 'down', 'left', 'right'
" }
"
" Route = List of Vectors
" Spies start at spawn position, follow vectors in order, loop back after last.

" ============================================================================
" Public API
" ============================================================================

" Calculate next position given current pos and vector
" @param pos: current [line, col]
" @param vector: vector dict with 'end' and 'dir'
" @return: next [line, col] (one step toward vector end)
function! Patrol_NextPos(pos, vector)
  let l:line = a:pos[0]
  let l:col = a:pos[1]

  if a:vector.dir == 'up'
    return [l:line - 1, l:col]
  elseif a:vector.dir == 'down'
    return [l:line + 1, l:col]
  elseif a:vector.dir == 'left'
    return [l:line, l:col - 1]
  elseif a:vector.dir == 'right'
    return [l:line, l:col + 1]
  endif

  " Unknown direction, don't move
  return a:pos
endfunction

" Check if current position has reached the vector's end
" @param pos: current [line, col]
" @param vector: vector dict with 'end' and 'dir'
" @return: 1 if at end, 0 otherwise
function! Patrol_IsVectorComplete(pos, vector)
  return a:pos[0] == a:vector.end[0] && a:pos[1] == a:vector.end[1]
endfunction

" Get next vector index (wraps around to 0 after last)
" @param route: list of vectors
" @param current_idx: current vector index
" @return: next vector index
function! Patrol_NextVector(route, current_idx)
  let l:next = a:current_idx + 1
  if l:next >= len(a:route)
    return 0
  endif
  return l:next
endfunction

" Validate that a route forms a valid loop
" @param spawn: [line, col] spawn position
" @param route: list of vectors
" @return: list of error strings (empty = valid)
function! Patrol_ValidateRoute(spawn, route)
  let l:errors = []

  if empty(a:route)
    call add(l:errors, 'Route is empty')
    return l:errors
  endif

  " Walk the route and verify it ends at spawn
  let l:pos = copy(a:spawn)

  for l:i in range(len(a:route))
    let l:vec = a:route[l:i]

    " Check vector has required fields
    if !has_key(l:vec, 'end') || !has_key(l:vec, 'dir')
      call add(l:errors, 'Vector ' . l:i . ' missing end or dir')
      continue
    endif

    " Walk to end of this vector
    let l:pos = l:vec.end
  endfor

  " Check if final position matches spawn (route loops)
  if l:pos[0] != a:spawn[0] || l:pos[1] != a:spawn[1]
    call add(l:errors, 'Route does not loop back to spawn. Ends at [' . l:pos[0] . ',' . l:pos[1] . '], spawn is [' . a:spawn[0] . ',' . a:spawn[1] . ']')
  endif

  return l:errors
endfunction
