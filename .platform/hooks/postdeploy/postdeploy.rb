#!/opt/elasticbeanstalk/lib/ruby/bin/ruby
# frozen_string_literal: true

require 'open3'

def main
  init
  update_motd
  finish  
end

def init
  abort 'Must be root' unless Process.uid == 0
end

def update_motd
  run('update-motd')
end

def finish
  log('Postdeploy done')  
end

def run(cmd, ignore_errors: false)
  log("Run: #{cmd}")
  stdout_str, stderr_str, status = Open3.capture3(cmd)
  unless status.success?
    message = "Error running: #{cmd}\nOutput: #{stdout_str}, Errors: #{stderr_str}"
    log(message)
    abort(message) unless ignore_errors
  end
  { stdout: stdout_str, stderr: stderr_str, status: status }
end

def log(message)
  puts message
  File.open('/var/log/deploy.log', 'a') { |f| f.print "#{Time.now.utc} #{message}\n" }
end

main
