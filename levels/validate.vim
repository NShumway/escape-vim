" Level Validation for Escape Vim
" Validates level definitions at build time.
"
" IMPORTANT: Maze dimensions are measured in CHARACTERS (Unicode code points),
" not bytes. The wall character █ is 3 bytes in UTF-8 but counts as 1 character.
" All position references (start_cursor, exit_cursor, spy positions) use
" 1-indexed character positions.
"
" Usage:
"   ./src/vim --clean -es -N \
"     -c 'set encoding=utf-8' \
"     -c 'source levels/validate.vim' \
"     -c 'let errors = Validate_All()' \
"     -c 'for e in errors | echom e | endfor' \
"     -c 'if !empty(errors) | cq | endif' \
"     -c 'qa!'

" Ensure UTF-8 encoding for correct character counting
set encoding=utf-8

" ============================================================================
" Public API
" ============================================================================

" Validate a single level
" @param level_path: path to level directory (e.g., 'levels/level01')
" @return: list of error strings (empty = valid)
function! Validate_Level(level_path)
  let l:errors = []

  " Load metadata
  let l:meta_path = a:level_path . '/meta.vim'
  if !filereadable(l:meta_path)
    call add(l:errors, a:level_path . ': meta.vim not found')
    return l:errors
  endif
  let l:meta = eval(join(readfile(l:meta_path), ''))

  " Load maze
  let l:maze_path = a:level_path . '/maze.txt'
  if !filereadable(l:maze_path)
    call add(l:errors, a:level_path . ': maze.txt not found')
    return l:errors
  endif
  let l:maze_lines = readfile(l:maze_path)

  " Measure actual maze dimensions
  let l:actual_rows = len(l:maze_lines)
  let l:actual_cols = 0
  for l:line in l:maze_lines
    let l:len = strchars(l:line)
    if l:len > l:actual_cols
      let l:actual_cols = l:len
    endif
  endfor

  " 1. Validate maze dimensions match metadata
  let l:errors += s:ValidateMazeDimensions(a:level_path, l:meta, l:actual_rows, l:actual_cols)

  " 2. Validate bounds (start/exit inside maze and not on walls)
  let l:errors += s:ValidateBounds(a:level_path, l:meta, l:maze_lines, l:actual_rows, l:actual_cols)

  " 3. Validate spies (if present)
  if has_key(l:meta, 'spies')
    let l:errors += s:ValidateSpies(a:level_path, l:meta.spies, l:maze_lines, l:actual_rows, l:actual_cols)
  endif

  return l:errors
endfunction

" Validate all levels in manifest
" @return: list of all error strings across all levels
function! Validate_All()
  let l:all_errors = []

  " Find all level directories
  let l:level_dirs = glob('levels/level*/', 0, 1)
  for l:level_dir in l:level_dirs
    " Remove trailing slash
    let l:path = substitute(l:level_dir, '/$', '', '')
    let l:errors = Validate_Level(l:path)
    let l:all_errors += l:errors
  endfor

  return l:all_errors
endfunction

" ============================================================================
" Validation Checks
" ============================================================================

" Validate maze dimensions match metadata
function! s:ValidateMazeDimensions(level_path, meta, actual_rows, actual_cols)
  let l:errors = []

  if !has_key(a:meta, 'maze')
    call add(l:errors, a:level_path . ': missing "maze" in metadata')
    return l:errors
  endif

  let l:maze_meta = a:meta.maze
  let l:expected_rows = get(l:maze_meta, 'lines', 0)
  let l:expected_cols = get(l:maze_meta, 'cols', 0)

  if l:expected_rows != a:actual_rows
    call add(l:errors, a:level_path . ': maze.lines mismatch - meta says ' .
          \ l:expected_rows . ', actual is ' . a:actual_rows)
  endif

  if l:expected_cols != a:actual_cols
    call add(l:errors, a:level_path . ': maze.cols mismatch - meta says ' .
          \ l:expected_cols . ', actual is ' . a:actual_cols)
  endif

  return l:errors
endfunction

" Validate start/exit positions
function! s:ValidateBounds(level_path, meta, maze_lines, rows, cols)
  let l:errors = []

  " Check start_cursor
  if has_key(a:meta, 'start_cursor')
    let l:start = a:meta.start_cursor
    let l:err = s:CheckPosition(a:level_path, 'start_cursor', l:start, a:maze_lines, a:rows, a:cols)
    if l:err != ''
      call add(l:errors, l:err)
    endif
  else
    call add(l:errors, a:level_path . ': missing start_cursor')
  endif

  " Check exit_cursor
  if has_key(a:meta, 'exit_cursor')
    let l:exit = a:meta.exit_cursor
    let l:err = s:CheckPosition(a:level_path, 'exit_cursor', l:exit, a:maze_lines, a:rows, a:cols)
    if l:err != ''
      call add(l:errors, l:err)
    endif
  else
    call add(l:errors, a:level_path . ': missing exit_cursor')
  endif

  return l:errors
endfunction

" Validate spy definitions
function! s:ValidateSpies(level_path, spies, maze_lines, rows, cols)
  let l:errors = []

  for l:spy in a:spies
    let l:id = get(l:spy, 'id', 'unknown')
    let l:prefix = a:level_path . ' spy "' . l:id . '"'

    " Check spawn position
    if has_key(l:spy, 'spawn')
      let l:err = s:CheckPosition(l:prefix, 'spawn', l:spy.spawn, a:maze_lines, a:rows, a:cols)
      if l:err != ''
        call add(l:errors, l:err)
      endif
    else
      call add(l:errors, l:prefix . ': missing spawn position')
    endif

    " Check route
    if has_key(l:spy, 'route')
      let l:route_errors = s:ValidateRoute(l:prefix, l:spy.spawn, l:spy.route, a:maze_lines, a:rows, a:cols)
      let l:errors += l:route_errors
    else
      call add(l:errors, l:prefix . ': missing route')
    endif
  endfor

  return l:errors
endfunction

" Validate a patrol route
function! s:ValidateRoute(prefix, spawn, route, maze_lines, rows, cols)
  let l:errors = []

  if empty(a:route)
    call add(l:errors, a:prefix . ': empty route')
    return l:errors
  endif

  " Walk the route from spawn position
  let l:pos = copy(a:spawn)

  for l:i in range(len(a:route))
    let l:vector = a:route[l:i]
    let l:target = l:vector.end
    let l:dir = l:vector.dir

    " Walk step by step to target
    while l:pos != l:target
      " Move one step
      if l:dir == 'up'
        let l:pos[0] -= 1
      elseif l:dir == 'down'
        let l:pos[0] += 1
      elseif l:dir == 'left'
        let l:pos[1] -= 1
      elseif l:dir == 'right'
        let l:pos[1] += 1
      else
        call add(l:errors, a:prefix . ': invalid direction "' . l:dir . '"')
        return l:errors
      endif

      " Check bounds
      if l:pos[0] < 1 || l:pos[0] > a:rows || l:pos[1] < 1 || l:pos[1] > a:cols
        call add(l:errors, a:prefix . ': route goes out of bounds at [' . l:pos[0] . ', ' . l:pos[1] . ']')
        return l:errors
      endif

      " Check for wall (positions are 1-indexed, maze_lines is 0-indexed)
      let l:char = s:GetCharAt(a:maze_lines, l:pos[0], l:pos[1])
      if l:char == '█'
        call add(l:errors, a:prefix . ': route hits wall at [' . l:pos[0] . ', ' . l:pos[1] . ']')
        return l:errors
      endif
    endwhile
  endfor

  " Check route loops back to spawn
  if l:pos != a:spawn
    call add(l:errors, a:prefix . ': route ends at [' . l:pos[0] . ', ' . l:pos[1] .
          \ '] instead of spawn [' . a:spawn[0] . ', ' . a:spawn[1] . ']')
  endif

  return l:errors
endfunction

" ============================================================================
" Helper Functions
" ============================================================================

" Check a position is valid (in bounds and not on wall)
" @return: error string or empty string if valid
function! s:CheckPosition(prefix, name, pos, maze_lines, rows, cols)
  let l:line = a:pos[0]
  let l:col = a:pos[1]

  " Check bounds (positions are 1-indexed)
  if l:line < 1 || l:line > a:rows
    return a:prefix . ': ' . a:name . ' line ' . l:line . ' out of bounds (1-' . a:rows . ')'
  endif
  if l:col < 1 || l:col > a:cols
    return a:prefix . ': ' . a:name . ' col ' . l:col . ' out of bounds (1-' . a:cols . ')'
  endif

  " Check not on wall
  let l:char = s:GetCharAt(a:maze_lines, l:line, l:col)
  if l:char == '█'
    return a:prefix . ': ' . a:name . ' [' . l:line . ', ' . l:col . '] is on a wall'
  endif

  return ''
endfunction

" Get character at position (1-indexed)
function! s:GetCharAt(maze_lines, line, col)
  if a:line < 1 || a:line > len(a:maze_lines)
    return ''
  endif
  let l:row = a:maze_lines[a:line - 1]
  return strcharpart(l:row, a:col - 1, 1)
endfunction
