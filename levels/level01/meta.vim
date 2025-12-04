{
  'title': 'First Steps',
  'description': 'Learn hjkl and basic mode switching.',
  'objective': 'Navigate to the exit and escape.',
  'commands': [
    {'key': 'h', 'desc': 'move left'},
    {'key': 'j', 'desc': 'move down'},
    {'key': 'k', 'desc': 'move up'},
    {'key': 'l', 'desc': 'move right'},
    {'key': ':q', 'desc': 'escape (at exit)'},
  ],
  'quote': "Every expert was once a beginner.\nEvery master was once a disaster.\n\nToday, you take your first steps.",
  'victory_quote': "Well done, soldier. You've taken your\nfirst steps toward freedom.\n\nBut don't celebrate yet. The real\nchallenges lie ahead.",
  'start_cursor': [2, 2],
  'exit_cursor': [36, 45],
  'viewport': {'lines': 15, 'cols': 40},
  'blocked_categories': ['arrows', 'search', 'find_char', 'word_motion',
                         'line_jump', 'paragraph', 'matching', 'marks',
                         'jump_list', 'scroll', 'insert', 'change',
                         'delete', 'visual', 'undo_redo'],
  'time_limit_seconds': v:null,
  'max_keystrokes': v:null
}
