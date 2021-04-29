#!/usr/bin/env ruby

require 'open3'
require 'fileutils'

def main
  check_root
  enable_amazon_linux_extras
  install_epel_repo
  install_nodejs_repo
  install_yarn_repo
  install_yum_packages
end

AMAZON_LINUX_EXTRAS = %w[epel postgresql10]
YUM_PACKAGES = [ 
  { package: 'htop', creates: '/usr/bin/htop' },
  { package: 'strace', creates: '/usr/bin/strace' },
  { package: 'the_silver_searcher', creates: '/usr/bin/ag' },
  { package: 'ncdu', creates: '/usr/bin/ncdu' },
  { package: 'nodejs', creates: '/usr/bin/node' },
  { package: 'yarn', creates: '/usr/bin/yarn' },
  { package: 'postgresql', creates: '/usr/bin/psql' },
  { package: 'https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox-0.12.6-1.amazonlinux2.x86_64.rpm', creates: '/usr/local/bin/wkhtmltopdf' }
]

def check_root
  abort 'Must be root' unless Process.uid == 0
end

def enable_amazon_linux_extras
  extras = File.read('/etc/yum.repos.d/amzn2-extras.repo')
  to_enable = AMAZON_LINUX_EXTRAS.reject { |item| extras.match?(/\[amzn2extra-#{item}\]\nenabled = 1/) }
  return if to_enable.empty?

  run("amazon-linux-extras enable #{to_enable.join(' ')}")
end

def install_epel_repo
  return if File.exists?('/etc/yum.repos.d/epel.repo')

  run("yum -y install epel-release")
end

def install_nodejs_repo
  FileUtils.rm_rf('/opt/elasticbeanstalk/support/node-install')
  FileUtils.rm_f('/usr/bin/node') if File.symlink?('/usr/bin/node')
  
  run("curl -sL https://rpm.nodesource.com/setup_14.x | bash -")
end

def install_yarn_repo  
  return if File.exists?('/etc/yum.repos.d/yarn.repo')

  run("curl -sL https://dl.yarnpkg.com/rpm/yarn.repo > /etc/yum.repos.d/yarn.repo")
end

def install_yum_packages
  to_install = YUM_PACKAGES.reject { |item| File.exists?(item[:creates]) } \
                                  .map { |item| item[:package] }
  return if to_install.empty?

  run("yum -y install #{to_install.join(' ')}")
end

def run(cmd, ignore_error: false)
  puts "Running: #{cmd}"
  stdout_str, stderr_str, status = Open3.capture3(cmd)  
  abort "Error running: #{cmd}\nOutput: #{stdout_str}, Errors: #{stderr_str}" unless status.success?
  { stdout: stdout_str, stderr: stderr_str, status: status }
end

main
