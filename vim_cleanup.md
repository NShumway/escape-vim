# Vim Fork Cleanup Plan

This document lists files and directories from the original Vim source that can be removed from the Escape Vim game fork. The repository is currently ~186 MB; removing these files could save ~45+ MB (24%).

## Priority Legend
- **P1**: Safe to remove immediately - no impact on game
- **P2**: Can remove if not targeting that platform
- **P3**: Remove with caution - verify not used first

---

## P1: Safe to Remove (No Impact)

### Top-Level Documentation
```
CONTRIBUTING.md          # Vim project contribution guide
README.txt               # Original Vim README
README_VIM9.md           # Vim 9 features guide
SECURITY.md              # Vim security policy
uninstall.txt            # Vim uninstall instructions
Filelist                 # File manifest for Vim distribution
vimtutor.bat             # Windows tutorial launcher
vimtutor.com             # DOS tutorial launcher
.hgignore                # Mercurial ignore (legacy VCS)
```

### READMEdir/ (Platform Documentation)
```
READMEdir/               # Entire directory (~3 MB)
  README_ami.txt         # Amiga
  README_amibin.txt
  README_amisrc.txt
  README_bindos.txt      # DOS
  README_dos.txt
  README_extra.txt
  README_haiku.txt       # Haiku OS
  README_mac.txt         # macOS (ironic, but not needed for game)
  README_ole.txt         # OLE/COM
  README_os2.txt         # OS/2
  README_os390.txt       # Mainframe
  README_src.txt
  README_srcdos.txt
  README_unix.txt
  README_vimlogo.txt
  README_vms.txt         # VMS
  README_w32s.txt        # Win32s
  Contents
  *.info                 # All .info metadata files
```

### Translation Files (~9.6 MB)
```
src/po/                  # Entire directory
  *.po                   # 60 translation files (fr, de, ja, zh_CN, etc.)
  Make_ming.mak
  Make_cyg.mak
  Make_mvc.mak
  big5corr.c
  fixfilenames.vim
  cleanup.vim

lang/                    # License translations
  LICENSE.it.txt
  LICENSE.pt_br.txt
  LICENSE.ru.txt
  README.it.txt
  README.pt_br.txt
  README.ru.txt
```

### Tutorial Files (~2.8 MB)
```
runtime/tutor/           # Entire directory
  tutor1                 # Base English tutorial
  tutor1.*               # All language variants (de, fr, es, etc.)
  tutor2
  tutor2.*
  tutor.vim
  tutor.tutor
  en/
  it/
  ru/
  sr/
```

### Test Suite (~16 MB)
```
src/testdir/             # Entire directory
  test_*.vim             # 373 test files
  dumps/                 # 1706 dump files
  samples/
  *.py                   # Python test support
```

### CI/Automation
```
ci/                      # Entire directory
  appveyor.bat
  *.sed
  hlgroups.*
  lychee.toml
  pinned-pkgs
  setup-*.sh

.github/                 # GitHub automation (keep if using GitHub)
  FUNDING.yml
  dependabot.yml
  labeler.yml
  MAINTAINERS
  ISSUE_TEMPLATE/

.codecov.yml
```

### Windows Installer
```
nsis/                    # Entire directory (~680 KB)
  gvim.nsi
  auxiliary.nsh
  Makefile
  Make_mvc.mak
  icons.zip
  README.txt
  lang/                  # 16 language packs
```

### Miscellaneous
```
.swp                     # Vim swap file (temporary)
tools/rename.bat         # Windows renaming tool
scripts/                 # Empty directory (only .gitkeep)
.claude/VIMTutor.pdf     # Reference PDF
```

---

## P2: Platform-Specific (Remove if Not Targeting)

### Windows Support
```
src/os_w32dll.c
src/os_w32exe.c
src/os_win32.c           # Large file
src/os_win32.h
src/gui_w32.c
src/gui_w32_rc.h
src/iscygpty.c
src/iscygpty.h
src/Make_ming.mak
src/Make_cyg.mak
src/Make_cyg_ming.mak
src/Make_mvc.mak
```

### Obsolete Platforms (Amiga, QNX, VMS)
```
src/os_amiga.c
src/os_amiga.h
src/os_qnx.c
src/os_qnx.h
src/os_vms.c
src/os_vms_conf.h
src/os_vms_fix.com
src/os_vms_mms.c
src/Make_ami.mak
src/Make_vms.mms
```

### Haiku OS
```
src/gui_haiku.cc
src/gui_haiku.h
src/os_haiku.rdef.in
```

### X11/Linux GUI
```
src/gui_gtk.c
src/gui_gtk_f.c
src/gui_gtk_f.h
src/gui_gtk_res.xml
src/gui_gtk_vms.h
src/gui_gtk_x11.c
src/gui_x11.c
src/gui_x11_pm.h
src/gui_xim.c
src/gui_xmdlg.c
src/gui_xmebw.c
src/gui_xmebw.h
src/gui_xmebw_p.h
src/gui_motif.c
src/gui_photon.c
src/wayland.c
src/wayland.h
```

---

## P3: Optional Features (Verify Before Removing)

### Scripting Language Integrations
```
src/if_python.c          # Python 2
src/if_python3.c         # Python 3
src/if_py_both.h
src/if_lua.c             # Lua
src/if_mzsch.c           # MzScheme
src/if_mzsch.h
src/if_ruby.c            # Ruby
src/if_perl.xs           # Perl
src/if_tcl.c             # Tcl
```

### Advanced Features (Probably Not Needed for Game)
```
src/if_cscope.c          # Code search
src/if_ole.cpp           # OLE/COM
src/if_ole.h
src/if_ole.idl
src/iid_ole.c
src/netbeans.c           # NetBeans integration
src/nbdebug.c
src/nbdebug.h
src/gui_beval.c          # Balloon tooltips
```

### Test Helper Code
```
src/json_test.c
src/kword_test.c
src/memfile_test.c
```

---

## P3: Documentation (Consider Keeping Some)

### runtime/doc/ (~11 MB)
The help files in `runtime/doc/` are extensive. Options:
1. **Remove all** - Users won't need `:help` in a game
2. **Keep minimal** - Just `help.txt`, `intro.txt`, `motion.txt`, `editing.txt`
3. **Keep all** - Educational value for learning Vim through the game

```
runtime/doc/             # 238 .txt files
  # Foreign language docs (can definitely remove):
  *_fr.txt
  *_ja.txt
  # etc.
```

---

## Files to KEEP

### Game-Specific (Critical)
```
game/                    # Game engine and UI
levels/                  # Level definitions
assets/                  # Game assets
prd_*.md                 # Product requirements
.claude/                 # Project notes (except VIMTutor.pdf)
```

### Core Vim Source
```
src/*.c                  # Core C source (except platform-specific)
src/*.h                  # Core headers
src/Makefile
src/configure
src/configure.ac
Makefile                 # Top-level build
configure
```

### Runtime Essentials
```
runtime/syntax/          # Syntax highlighting
runtime/colors/          # Color schemes
runtime/autoload/        # Autoload scripts
runtime/plugin/          # Core plugins
runtime/ftplugin/        # Filetype plugins
runtime/indent/          # Indentation rules
```

---

## Execution Plan

### Phase 1: Quick Wins (P1 items)
1. Remove `CONTRIBUTING.md`, `README.txt`, `README_VIM9.md`, etc.
2. Remove `READMEdir/` entirely
3. Remove `src/po/` (translations)
4. Remove `runtime/tutor/` (tutorials)
5. Remove `nsis/` (Windows installer)
6. Remove `ci/` (CI configs)

### Phase 2: Platform Cleanup (P2 items)
1. Decide target platforms (macOS only? Linux too?)
2. Remove unused platform code
3. Update Makefile if needed

### Phase 3: Feature Trimming (P3 items)
1. Verify no game code uses scripting integrations
2. Remove unused interpreter support
3. Decide on documentation strategy

---

## Estimated Savings

| Category | Size |
|----------|------|
| Translations (src/po/) | ~9.6 MB |
| Test suite (src/testdir/) | ~16 MB |
| Documentation (runtime/doc/ + tutor/) | ~14 MB |
| Platform-specific code | ~5 MB |
| READMEdir/ | ~0.5 MB |
| CI/Installer | ~1 MB |
| **Total** | **~46 MB** |

This would reduce the repository from ~186 MB to ~140 MB (25% reduction).
