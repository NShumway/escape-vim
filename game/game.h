/* vi:set ts=8 sts=4 sw=4 noet:
 *
 * game.h - Escape Room: Vim game state and hooks
 */

#ifndef GAME_H
#define GAME_H

/*
 * Set the exit position for the current level.
 * row and col are 1-indexed (vim convention).
 * Set to (0, 0) when leaving a level.
 */
void game_set_exit(int row, int col);

/*
 * Check if currently in a level (exit position set).
 */
int game_in_level(void);

/*
 * Check if game is active (in a level where :q should be intercepted).
 * Returns 1 if in a level, 0 otherwise.
 * When not active, :q should quit Vim entirely.
 */
int game_is_active(void);

/*
 * Check if win conditions are met.
 * Returns 1 if cursor is at the exit position (win), 0 otherwise (fail).
 */
int game_check_win_conditions(void);

#endif /* GAME_H */
