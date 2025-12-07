{
  'title': 'The Watchers',
  'description': 'Evade patrolling spies to reach the exit.',
  'objective': 'Navigate past the guards without being detected.',
  'commands': [
    {'key': 'h', 'desc': 'move left'},
    {'key': 'j', 'desc': 'move down'},
    {'key': 'k', 'desc': 'move up'},
    {'key': 'l', 'desc': 'move right'},
    {'key': ':q', 'desc': 'escape (at exit)'},
  ],
  'quote': "Patience is not the ability to wait,\nbut the ability to keep a good attitude\nwhile waiting.\n\nThe Watchers never tire. You must be smarter.",
  'victory_quote': "Impressive. You slipped past the\nWatchers like a ghost.\n\nFew have made it this far.\nYou're proving to be quite capable.",
  'start_cursor': [3, 3],
  'exit_cursor': [48, 98],
  'maze': {'lines': 50, 'cols': 100},
  'viewport': {'lines': 50, 'cols': 100},
  'blocked_categories': ['arrows', 'search', 'find_char', 'word_motion', 'line_jump', 'paragraph', 'matching', 'marks', 'jump_list', 'scroll', 'insert', 'change', 'delete', 'visual', 'undo_redo'],
  'features': ['spies'],
  'time_limit_seconds': v:null,
  'max_keystrokes': v:null
}