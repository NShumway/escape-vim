" Level 3 Logic - The Watchers
" Sets up spy collision detection for defeat

" Set defeat callback: if player touches spy, trigger level failure
call Collision_SetSpyCallback({-> Game_LevelFailed()})
