#!/usr/bin/env ruby
# frozen_string_literal: true

require 'open3'
require 'fileutils'

def main
  check_root
  copy_files
  install_repos
  install_yum_packages
end

FILES = [
  { source: 'puma/pumaconf.rb', target: '/opt/elasticbeanstalk/config/private/pumaconf.rb' }
]

AMAZON_LINUX_EXTRAS = %w[epel postgresql10]

WKHTMLTOPDF_RPM_URL = \
  'https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox-0.12.6-1.amazonlinux2.x86_64.rpm'

YUM_PACKAGES = [
  { package: 'htop', creates: '/usr/bin/htop' },
  { package: 'strace', creates: '/usr/bin/strace' },
  { package: 'the_silver_searcher', creates: '/usr/bin/ag' },
  { package: 'ncdu', creates: '/usr/bin/ncdu' },
  { package: 'nodejs', creates: '/usr/bin/node' },
  { package: 'yarn', creates: '/usr/bin/yarn' },
  { package: 'postgresql', creates: '/usr/bin/psql' },
  { package: 'libsodium', creates: '/usr/lib64/libsodium.so.*' },
  { package: WKHTMLTOPDF_RPM_URL, creates: '/usr/local/bin/wkhtmltopdf' }
]

def install_repos
  enable_amazon_linux_extras
  install_epel_repo
  install_nodejs_repo
  install_yarn_repo
end

def check_root
  abort 'Must be root' unless Process.uid == 0
end

def copy_files
  FILES.each do |file|
    source = "#{__dir__}/files/#{file[:source]}"
    target = file[:target]
    next if File.exist?(target) && FileUtils.compare_file(source, target)

    FileUtils.cp(source, target)
    log("Copy: #{source} to #{target}")
  end
end

def enable_amazon_linux_extras
  extras = File.read('/etc/yum.repos.d/amzn2-extras.repo')
  to_enable = AMAZON_LINUX_EXTRAS.reject { |item| extras.match?(/\[amzn2extra-#{item}\]\nenabled = 1/) }
  return if to_enable.empty?

  run("amazon-linux-extras enable #{to_enable.join(' ')}")
end

def install_epel_repo
  return if File.exist?('/etc/yum.repos.d/epel.repo')

  run('yum -y install epel-release')
end

def install_nodejs_repo
  return if File.exist?('/etc/yum.repos.d/nodesource-el7.repo')

  FileUtils.rm_rf('/opt/elasticbeanstalk/support/node-install')
  FileUtils.rm_f('/usr/bin/node') if File.symlink?('/usr/bin/node')

  run('curl -sL https://rpm.nodesource.com/setup_14.x | bash -')
end

def install_yarn_repo
  return if File.exist?('/etc/yum.repos.d/yarn.repo')

  run('curl -sL https://dl.yarnpkg.com/rpm/yarn.repo > /etc/yum.repos.d/yarn.repo')
end

def install_yum_packages
  to_install = YUM_PACKAGES.reject { |item| Dir.glob(item[:creates]).any? } \
                           .map { |item| item[:package] }
  return if to_install.empty?

  run("yum -y install #{to_install.join(' ')}")
end

def run(cmd)
  log("Run: #{cmd}")
  stdout_str, stderr_str, status = Open3.capture3(cmd)
  unless status.success?
    message = "Error running: #{cmd}\nOutput: #{stdout_str}, Errors: #{stderr_str}"
    log(message)
    abort(message)
  end
  { stdout: stdout_str, stderr: stderr_str, status: status }
end

def log(message)
  puts message
  File.open('/var/log/prebuild.log', 'a') { |f| f.print "#{Time.now.utc} #{message}\n" }
end

main
