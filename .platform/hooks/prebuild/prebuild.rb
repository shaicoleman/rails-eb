#!/usr/bin/env ruby

require 'open3'

def main
  enable_amazon_linux_extras
  install_epel
  install_yum_packages
end

AMAZON_LINUX_EXTRAS = %w[epel postgresql10]
YUM_PACKAGES = [ 
  { package: 'htop', creates: '/usr/bin/htop' },
  { package: 'strace', creates: '/usr/bin/strace' },
  { package: 'the_silver_searcher', creates: '/usr/bin/ag' },
  { package: 'ncdu', creates: '/usr/bin/ncdu' },
  { package: 'postgresql', creates: '/usr/bin/psql' },
  { package: 'https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox-0.12.6-1.amazonlinux2.x86_64.rpm', creates: '/usr/local/bin/wkhtmltopdf' }
]

def enable_amazon_linux_extras
  extras = File.read('/etc/yum.repos.d/amzn2-extras.repo')
  to_enable = AMAZON_LINUX_EXTRAS.reject { |item| extras.match?(/\[amzn2extra-#{item}\]\nenabled = 1/) }

  return if to_enable.empty?

  run("amazon-linux-extras enable #{to_enable.join(' ')}")
end

def install_epel
  run("yum -y install epel-release") unless File.exists?('/etc/yum.repos.d/epel.repo')
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
