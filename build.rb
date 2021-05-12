#!/usr/bin/env ruby

require 'fileutils'
require 'time'
require 'byebug'
require 'yaml'

EXCLUDES = %w[vendor/bundle .build .git .bundle build.rb deploy.sh .byebug_history]

def main
  configure_elastic_beanstalk
  clean_old_build
  write_build_info
  docker_build
  copy_app
  add_metadata
end

def configure_elastic_beanstalk
  yaml = File.read('.elasticbeanstalk/config.yml')
  new_yaml = yaml.gsub(/^(deploy:\s*\n(?:\s+.*\n)*)/, '').chomp
  new_yaml << "\ndeploy:\n  artifact: .build/app.zip\n"
  File.write('.elasticbeanstalk/config.yml', new_yaml) if yaml != new_yaml
end

def clean_old_build
  FileUtils.rm_rf('.build')
  FileUtils.mkdir_p('.build')
end

def write_build_info
  build_info = <<~EOT
    Branch: #{`git rev-parse --abbrev-ref HEAD`.chomp}
    Commit: #{`git rev-parse --short=7 HEAD`.chomp}
    Message: #{`git show-branch --no-name HEAD`.chomp}
    User: #{`whoami`.chomp}
    Time: #{Time.now.utc.iso8601}
  EOT
  File.write('.build/build-info.txt', build_info)
end

def docker_build
  puts `docker/build.sh`
end

def copy_app
  container_id = `docker create --rm al2`.chomp
  `docker cp #{container_id}:/home/webapp/build/app.zip .build/app.zip`
  `docker rm #{container_id}`
end

def add_metadata
  `zip -r .build/app.zip .build/build-info.txt .platform`
end

main
