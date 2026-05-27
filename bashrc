[[ $- == *i* ]] || return

if [ -f /etc/bashrc ]; then
  . /etc/bashrc
fi

if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
  PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

if [ -d ~/.bashrc.d ]; then
  for rc in ~/.bashrc.d/*; do
    if [ -f "$rc" ]; then
      . "$rc"
    fi
  done
fi
unset rc

alias cll="clear && ls -la"

fortune | cowsay -r | lolcat
eval "$(starship init bash)"
export TERM=xterm-256color

if [ -f "$HOME/.cargo/env" ]; then
  . "$HOME/.cargo/env"
fi

if [[ -t 0 ]] && [[ -z "$TMUX" ]]; then
  tmux new-session -A -s main
fi
