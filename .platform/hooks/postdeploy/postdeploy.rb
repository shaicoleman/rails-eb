#!/opt/elasticbeanstalk/lib/ruby/bin/ruby
# frozen_string_literal: true

require_relative '../prebuild/build_utils'

def main
  init
  update_motd
  finish  
end

def update_motd
  run('update-motd')
end

main
