/* vi:set ts=8 sts=4 sw=4 noet:
 *
 * game.c - Escape Room: Vim game state and hooks
 */

#include "vim.h"
#include "game.h"

/* Exit position for current level (1-indexed, 0 = not in level) */
static int exit_row = 0;
static int exit_col = 0;

/*
 * Set the exit position for the current level.
 * Set to (0, 0) when leaving a level.
 */
    void
game_set_exit(int row, int col)
{
    exit_row = row;
    exit_col = col;
}

/*
 * Check if currently in a level (exit position set).
 */
    int
game_in_level(void)
{
    return (exit_row > 0 && exit_col > 0);
}

/*
 * Check if game is active (in a level where :q should be intercepted).
 * This is an alias for game_in_level - when in a level, :q triggers
 * win/fail checks. When NOT in a level (between screens), :q quits Vim.
 */
    int
game_is_active(void)
{
    return game_in_level();
}

/*
 * Check if win conditions are met.
 * Returns 1 if cursor is at the exit position (win), 0 otherwise (fail).
 */
    int
game_check_win_conditions(void)
{
    int cur_row;
    int cur_col;

    if (!game_in_level())
	return 1;

    /* Get current cursor position (1-indexed) */
    cur_row = curwin->w_cursor.lnum;
    cur_col = curwin->w_cursor.col + 1;  /* col is 0-indexed, convert to 1 */

    return (cur_row == exit_row && cur_col == exit_col);
}

/*
 * Vimscript function: gamesetexit(row, col)
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
 * Vimscript function: gameinlevel()
 * Returns 1 if in a level, 0 otherwise.
 */
    void
f_game_in_level(typval_T *argvars UNUSED, typval_T *rettv)
{
    rettv->v_type = VAR_NUMBER;
    rettv->vval.v_number = game_in_level();
}

/*
 * Vimscript function: gamecheckquit()
 * Returns 1 if win conditions met (at exit), 0 otherwise.
 */
    void
f_game_check_quit(typval_T *argvars UNUSED, typval_T *rettv)
{
    rettv->v_type = VAR_NUMBER;
    rettv->vval.v_number = game_check_win_conditions();
}
