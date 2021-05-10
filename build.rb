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
  # copy_app
end

def configure_elastic_beanstalk
  yaml = File.read('.elasticbeanstalk/config.yml')
  new_yaml = yaml.gsub(/^(deploy:\s*\n(?:\s+.*\n)*)/, '').chomp
  new_yaml << "\ndeploy:\n  artifact: .build/app.zip\n"
  File.write('.elasticbeanstalk/config.yml', new_yaml) if yaml != new_yaml
end

def clean_old_build
  FileUtils.rm_rf(%w[_meta .build])
  FileUtils.mkdir_p(%w[_meta .build])
end

def write_build_info
  build_info = <<~EOT
    Branch: #{`git rev-parse --abbrev-ref HEAD`.chomp}
    Commit: #{`git rev-parse --short=7 HEAD`.chomp}
    Message: #{`git show-branch --no-name HEAD`.chomp}
    User: #{`whoami`.chomp}
    Time: #{Time.now.utc.iso8601}
  EOT
  File.write('_meta/build-info.txt', build_info)
end

def docker_build
  `docker/build.sh`
end

main
