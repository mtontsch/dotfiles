# tmux cheatsheet (my config)

Prefix = `C-a` (press, release, then the key). Config: `~/.config/tmux/tmux.conf`.

## Sessions (from the shell)

| Command | Action |
|---|---|
| `ta` | attach to `main`, create it if missing |
| `ta name` | attach to / create session `name` |
| `tmux ls` | list sessions |
| `tmux kill-session -t name` | kill a session |

## Inside tmux

### Sessions & windows

| Keys | Action |
|---|---|
| `C-a d` | detach (session keeps running) |
| `C-a S` | session/window picker (tree) |
| `C-a $` | rename session |
| `C-a c` | new window (same directory) |
| `C-a ,` | rename window |
| `C-a &` | kill window |
| `Shift-← / →` | previous / next window *(no prefix)* |
| `Alt-1 … Alt-9` | jump to window N *(no prefix)* |
| `C-a Tab` | last window |

### Panes

| Keys | Action |
|---|---|
| `C-a v` | split left/right |
| `C-a b` | split top/bottom |
| `Alt-arrows` | move between panes *(no prefix)* |
| `C-a h/j/k/l` | move between panes (vim) |
| `C-a H/J/K/L` | resize pane by 5 |
| `C-a z` | zoom pane (toggle fullscreen) |
| `C-a x` | kill pane |
| `C-a < / >` | swap pane up / down |
| `C-a Space` | cycle layouts |

### Copy mode (vim keys)

| Keys | Action |
|---|---|
| `C-a s` | enter copy mode / scrollback |
| `v` | start selection |
| `y` | copy selection and exit |
| `/` `?` | search down / up |
| `Esc` or `q` | leave copy mode |
| `C-a p` | paste |
| `C-a ä` | pick from paste history |

### Misc

| Keys | Action |
|---|---|
| `C-a r` | reload config |
| `C-a m` / `C-a M` | mouse on / off |
| `C-a ö` | show tmux messages |
| `C-a :` | command prompt |
| `C-a ?` | list all keybindings |
| `C-a C-a` | send a literal `C-a` (e.g. readline start-of-line) |
