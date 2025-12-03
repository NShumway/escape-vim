/* vi:set ts=8 sts=4 sw=4 noet:
 *
 * game.h - Escape Room: Vim game state and hooks
 */

#ifndef GAME_H
#define GAME_H

/*
 * Set the exit position for the current level.
 * row and col are 1-indexed (vim convention).
 * Called from Vimscript via GameSetExit(row, col).
 */
void game_set_exit(int row, int col);

/*
 * Check if the player is allowed to quit.
 * Returns 1 if cursor is at the exit position, 0 otherwise.
 * Called from ex_docmd.c when processing quit commands.
 */
int game_check_quit_allowed(void);

/*
 * Check if game mode is active.
 * Returns 1 if an exit position has been set, 0 otherwise.
 */
int game_is_active(void);

#endif /* GAME_H */
