directory '/var/app/current'
workers_count = Integer(ENV.fetch("WEB_CONCURRENCY") { 2 })
threads_count = Integer(ENV.fetch("RAILS_MAX_THREADS") { 5 })
workers workers_count
threads threads_count, threads_count
preload_app! if workers_count > 0
bind 'unix:///var/run/puma/my_app.sock'
stdout_redirect '/var/log/puma/puma.log', '/var/log/puma/puma.log', true
daemonize false
