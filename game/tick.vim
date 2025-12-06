" Tick System for Escape Vim
" Central heartbeat for all time-based game behavior

" ============================================================================
" Configuration
" ============================================================================

let s:TICK_INTERVAL_MS = 50  " Base tick rate: 20 ticks/second

" ============================================================================
" State
" ============================================================================

let s:tick_timer_id = -1
let s:current_tick = 0
let s:subscribers = {}  " id -> {Callback, interval, last_fired_tick}
let s:is_running = 0

" ============================================================================
" Public API
" ============================================================================

" Start the game clock
function! Tick_Start()
  if s:is_running
    return
  endif

  let s:is_running = 1
  let s:current_tick = 0

  " Reset all subscriber last_fired_tick to ensure they fire on schedule
  for l:id in keys(s:subscribers)
    let s:subscribers[l:id].last_fired_tick = 0
  endfor

  let s:tick_timer_id = timer_start(s:TICK_INTERVAL_MS, function('s:OnTick'), {'repeat': -1})
endfunction

" Stop the game clock
function! Tick_Stop()
  if !s:is_running
    return
  endif

  let s:is_running = 0

  if s:tick_timer_id >= 0
    call timer_stop(s:tick_timer_id)
    let s:tick_timer_id = -1
  endif
endfunction

" Register callback to fire every N ticks
" Callback receives current tick number as argument
" Callback should return 1 to stay subscribed, 0 to auto-unsubscribe
" @param id: unique string identifier for this subscriber
" @param Callback: funcref that takes (tick) and returns 0 or 1
" @param interval: number of ticks between calls (1 = every tick, 20 = every second)
function! Tick_Subscribe(id, Callback, interval)
  let s:subscribers[a:id] = {
        \ 'Callback': a:Callback,
        \ 'interval': a:interval,
        \ 'last_fired_tick': s:current_tick
        \ }
endfunction

" Remove a subscriber
" @param id: subscriber identifier
function! Tick_Unsubscribe(id)
  if has_key(s:subscribers, a:id)
    unlet s:subscribers[a:id]
  endif
endfunction

" Remove all subscribers with IDs starting with prefix
" @param prefix: string prefix to match (e.g., 'gameplay:')
function! Tick_UnsubscribePrefix(prefix)
  let l:to_remove = []
  for l:id in keys(s:subscribers)
    if l:id[:len(a:prefix)-1] ==# a:prefix
      call add(l:to_remove, l:id)
    endif
  endfor
  for l:id in l:to_remove
    unlet s:subscribers[l:id]
  endfor
endfunction

" Get current tick number
" @return: current tick count since Tick_Start()
function! Tick_GetCurrent()
  return s:current_tick
endfunction

" Check if clock is active
" @return: 1 if running, 0 if stopped
function! Tick_IsRunning()
  return s:is_running
endfunction

" ============================================================================
" One-Shot Helper
" ============================================================================

" Schedule a one-shot callback after N ticks
" @param id: unique identifier (will auto-unsubscribe after firing)
" @param ticks: number of ticks to wait
" @param Callback: funcref to call (receives tick number)
function! Tick_After(id, ticks, Callback)
  let l:target_tick = s:current_tick + a:ticks
  let l:CallbackRef = a:Callback

  " Create wrapper as a lambda - each call gets its own closure instance
  let l:Wrapper = {tick -> s:OneShotCheck(tick, l:target_tick, l:CallbackRef)}

  call Tick_Subscribe(a:id, l:Wrapper, 1)
endfunction

" Helper for one-shot tick callbacks (called from lambda closures)
function! s:OneShotCheck(tick, target_tick, Callback)
  if a:tick >= a:target_tick
    call a:Callback(a:tick)
    return 0  " Unsubscribe
  endif
  return 1  " Keep waiting
endfunction

" Convert milliseconds to ticks
" @param ms: milliseconds
" @return: number of ticks (rounded)
function! Tick_MsToTicks(ms)
  return float2nr(round(a:ms * 1.0 / s:TICK_INTERVAL_MS))
endfunction

" ============================================================================
" Internal
" ============================================================================

" Called every tick by the timer
function! s:OnTick(timer)
  let s:current_tick += 1

  " Collect subscribers to remove (can't modify dict while iterating)
  let l:to_remove = []

  " Fire subscribers that are due
  for l:id in keys(s:subscribers)
    let l:sub = s:subscribers[l:id]
    let l:ticks_since = s:current_tick - l:sub.last_fired_tick

    if l:ticks_since >= l:sub.interval
      " Fire the callback
      let l:keep = l:sub.Callback(s:current_tick)

      if l:keep
        " Update last fired tick
        let s:subscribers[l:id].last_fired_tick = s:current_tick
      else
        " Callback returned 0, schedule for removal
        call add(l:to_remove, l:id)
      endif
    endif
  endfor

  " Remove unsubscribed
  for l:id in l:to_remove
    call Tick_Unsubscribe(l:id)
  endfor
endfunction

" Reset tick system (for testing or game restart)
function! Tick_Reset()
  call Tick_Stop()
  let s:current_tick = 0
  let s:subscribers = {}
endfunction
