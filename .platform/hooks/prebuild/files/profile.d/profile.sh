set -o allexport
[[ -r /opt/elasticbeanstalk/deployment/env ]] && source /opt/elasticbeanstalk/deployment/env
set +o allexport

export PATH="$HOME/.local/bin:$HOME/bin:/opt/elasticbeanstalk/.rbenv/shims:/opt/elasticbeanstalk/.rbenv/bin:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin"

alias l='ls -Al'
alias vi='vim'
alias ncdu='ncdu --color=dark'
alias ag='rg --smart-case'
