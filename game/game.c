/* vi:set ts=8 sts=4 sw=4 noet:
 *
 * game.c - Escape Room: Vim game state and hooks
 */

#include "vim.h"
#include "game.h"

/* Exit position for the current level (1-indexed) */
static int exit_row = -1;
static int exit_col = -1;

/*
 * Set the exit position for the current level.
 */
    void
game_set_exit(int row, int col)
{
    exit_row = row;
    exit_col = col;
}

/*
 * Check if game mode is active.
 */
    int
game_is_active(void)
{
    return (exit_row > 0 && exit_col > 0);
}

/*
 * Check if the player is allowed to quit.
 * Returns 1 if cursor is at the exit position, 0 otherwise.
 */
    int
game_check_quit_allowed(void)
{
    int cur_row;
    int cur_col;

    /* If no exit set, allow quit (game not active) */
    if (!game_is_active())
	return 1;

    /* Get current cursor position (1-indexed) */
    cur_row = curwin->w_cursor.lnum;
    cur_col = curwin->w_cursor.col + 1;  /* col is 0-indexed, convert to 1 */

    return (cur_row == exit_row && cur_col == exit_col);
}

/*
 * Vimscript function: GameSetExit(row, col)
 * Sets the exit position for quit interception.
 */
    void
f_game_set_exit(typval_T *argvars, typval_T *rettv UNUSED)
{
    int row;
    int col;

    if (argvars[0].v_type != VAR_NUMBER || argvars[1].v_type != VAR_NUMBER)
    {
	emsg(_(e_number_required));
	return;
    }

    row = (int)tv_get_number(&argvars[0]);
    col = (int)tv_get_number(&argvars[1]);

    game_set_exit(row, col);
}

/*
 * Vimscript function: GameIsActive()
 * Returns 1 if game mode is active, 0 otherwise.
 */
    void
f_game_is_active(typval_T *argvars UNUSED, typval_T *rettv)
{
    rettv->v_type = VAR_NUMBER;
    rettv->vval.v_number = game_is_active();
}

/*
 * Vimscript function: GameCheckQuit()
 * Returns 1 if quit is allowed, 0 otherwise.
 */
    void
f_game_check_quit(typval_T *argvars UNUSED, typval_T *rettv)
{
    rettv->v_type = VAR_NUMBER;
    rettv->vval.v_number = game_check_quit_allowed();
}
