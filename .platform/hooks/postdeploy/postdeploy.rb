#!/opt/elasticbeanstalk/lib/ruby/bin/ruby
# frozen_string_literal: true

require_relative '../prebuild/build_utils'

def main
  init
  chown_env_file_to_webapp
  update_motd
  finish  
end

def chown_env_file_to_webapp
  FileUtils.chown 'webapp', 'webapp', '/opt/elasticbeanstalk/deployment/env'
end

def update_motd
  run('update-motd')
end

main
