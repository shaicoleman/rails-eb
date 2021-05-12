#!/opt/elasticbeanstalk/lib/ruby/bin/ruby
# frozen_string_literal: true

require 'open3'
require 'fileutils'

def main
  init
  enable_eatmydata
  enable_swap
  install_repos
  install_yum_packages
  cleanup_yum_packages
  autoremove_yum_packages
  copy_files
  create_symlinks
  run_handlers
  change_webapp_shell
  check_ruby_version
  upgrade_bundler
  finish
end

FILES = [
  { source: 'motd/10eb-banner', target: '/etc/update-motd.d/10eb-banner', handler: 'update_motd' },
  { source: 'profile.d/prompt.sh', target: '/etc/profile.d/prompt.sh' },
  { source: 'puma/pumaconf.rb', target: '/opt/elasticbeanstalk/config/private/pumaconf.rb' },
  { source: 'sysctl.d/local.conf', target: '/etc/sysctl.d/local.conf', handler: 'reload_sysctl' },
  { source: 'bin/rails-console', target: '/home/ec2-user/bin/rails-console' },
  { source: 'bin/rails-shell', target: '/home/ec2-user/bin/rails-shell' },
  { source: 'elasticbeanstalk/checkforraketask.rb', target: '/opt/elasticbeanstalk/config/private/checkforraketask.rb' },
  { source: 'nginx/nginx.conf', target: '/opt/elasticbeanstalk/config/private/nginx/nginx.conf.template' },
  { source: 'nginx/webapp.conf', target: '/opt/elasticbeanstalk/config/private/nginx/webapp.conf' }
]

SYMLINKS = [
  { source: '/usr/bin/vim', target: '/usr/local/sbin/vi' }
]

AMAZON_LINUX_EXTRAS = %w[epel postgresql10]

EATMYDATA_URL = 'https://ca-downloads.s3-eu-west-1.amazonaws.com/eatmydata/libeatmydata-0.1-00.21.el7.centos.x86_64.rpm'
FILE_URL = 'https://ca-downloads.s3-eu-west-1.amazonaws.com/file/file-5.39-5.amzn2.x86_64.rpm'
FILE_LIBS_URL = 'https://ca-downloads.s3-eu-west-1.amazonaws.com/file/file-libs-5.39-5.amzn2.x86_64.rpm'
WKHTMLTOPDF_RPM_URL = 'https://ca-downloads.s3-eu-west-1.amazonaws.com/wkhtmltopdf/wkhtmltox-0.12.6-1.amazonlinux2.x86_64.rpm'
DEEPSECURITY_URL = 'https://ca-downloads.s3-eu-west-1.amazonaws.com/deepsecurity/Agent-PGPCore-amzn2-20.0.0-2204.x86_64.rpm'

YUM_PACKAGES = [
  { package: 'htop', creates: '/usr/bin/htop' },
  { package: 'strace', creates: '/usr/bin/strace' },
  { package: 'the_silver_searcher', creates: '/usr/bin/ag' },
  { package: 'ncdu', creates: '/usr/bin/ncdu' },
  { package: 'mc', creates: '/usr/bin/mc' },
  { package: 'nodejs', creates: '/usr/bin/node' },
  { package: 'yarn', creates: '/usr/bin/yarn' },
  { package: 'postgresql', creates: '/usr/share/doc/postgresql-10.*' },
  { package: 'libsodium', creates: '/usr/lib64/libsodium.so.*' },
  { package: FILE_URL, creates: '/usr/share/doc/file-5.39' },
  { package: FILE_LIBS_URL, creates: '/usr/share/doc/file-libs-5.39' },
  { package: WKHTMLTOPDF_RPM_URL, creates: '/usr/local/bin/wkhtmltopdf' },
  # { package: DEEPSECURITY_URL, creates: '/opt/ds_agent/ds_agent' }
]

YUM_CLEANUP = [
  { package: 'mariadb*', removes: '/usr/bin/mysql' },
  { package: 'ImageMagick*', removes: '/usr/bin/Magick-config' },
  { package: 'postgres*-9*', removes: '/usr/share/doc/postgresql-9*' },
  { package: 'iptables*', removes: '/sbin/iptables' },
  { package: 'xfs*', removes: '/sbin/xfsdump' },
  { package: 'hunspell*', removes: '/bin/hunspell' },
  { package: 'tcsh', removes: '/bin/tcsh' }
]

def enable_swap
  return if File.read('/proc/swaps').include?('/swapfile')

  total_ram_kb = `cat /proc/meminfo`.match(/^MemTotal:\s+(\d+) kB/)&.captures.first&.to_i
  swap_size_kb = [total_ram_kb * 0.25, 1048576].max.ceil
  run("fallocate -l #{swap_size_kb}K /swapfile; mkswap -f /swapfile; chmod 600 /swapfile; swapon /swapfile")
end

# Only enabled on first run
def enable_eatmydata
  return File.exist?('/usr/bin/eatmydata')

  run("yum -y install #{EATMYDATA_URL}")
  ENV['LD_PRELOAD'] = '/usr/lib64/libeatmydata.so'
end

def install_repos
  enable_amazon_linux_extras
  install_epel_repo
  install_nodejs_repo
  install_yarn_repo
end

def init
  abort 'Must be root' unless Process.uid == 0
  @handlers = []
end

def finish
  log('Prebuild done')
end

def check_ruby_version
  return unless File.exist?('.ruby-version')
  
  expected_ruby_version = File.read('.ruby-version').strip
  current_ruby_version = `ruby -e 'print RUBY_VERSION'`
  unless expected_ruby_version == current_ruby_version
    log("Warning: .ruby-version mismatch - Expected: #{expected_ruby_version}, Current: #{current_ruby_version}. Renamed")
    FileUtils.mv('.ruby-version', '.ruby-version-mismatch')
  end
end

def upgrade_bundler
  gemfile_version = File.read('Gemfile.lock').match(/BUNDLED WITH\s+(\S+)/)&.captures&.first
  installed_version = `ruby -e "require 'bundler'; print Bundler::VERSION"`
  return if Gem::Version.new(installed_version) >= Gem::Version.new(gemfile_version)

  run('gem install bundler')
end

def copy_files
  FILES.each do |file|
    source = "#{__dir__}/files/#{file[:source]}"
    target = file[:target]
    next if File.exist?(target) && FileUtils.compare_file(source, target)

    FileUtils.mkdir_p(File.dirname(target))
    FileUtils.cp(source, target)
    log("Copy: #{source} to #{target}")
    add_handler(file[:handler])
  end
end

def create_symlinks
  SYMLINKS.each do |symlink|
    next if File.exist?(symlink[:target])

    FileUtils.ln_s(symlink[:source], symlink[:target])
    log("Symlink: #{symlink[:source]} to #{symlink[:target]}")
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

def cleanup_yum_packages
  to_cleanup = YUM_CLEANUP.select { |item| Dir.glob(item[:removes]).any? } \
                          .map { |item| item[:package] }
  return if to_cleanup.empty?

  run("yum -y erase #{to_cleanup.join(' ')}")
end

def install_yum_packages
  to_install = YUM_PACKAGES.reject { |item| Dir.glob(item[:creates]).any? } \
                           .map { |item| item[:package] }
  return if to_install.empty?

  run("yum -y install #{to_install.join(' ')}")
end

def autoremove_yum_packages
  run('yum -y autoremove') if File.exist?('/usr/bin/pango-list')
end

def reload_sysctl
  run('sysctl -p /etc/sysctl.d/local.conf', ignore_errors: true)
end

def update_motd
  run('update-motd')
end

def add_handler(handler)
  return unless handler

  @handlers << handler unless @handlers.include?(handler)
end

def run_handlers
  @handlers.each do |handler|
    send(handler)
  end
end

def change_webapp_shell
  return if File.read('/etc/passwd').match?(%r{^webapp:.*:/bin/bash$})

  run('usermod --shell /bin/bash webapp')
end

def run(cmd, ignore_errors: false)
  log("Run: #{cmd}")
  stdout_str, stderr_str, status = Open3.capture3(cmd)
  unless status.success?
    message = "Error running: #{cmd}\nOutput: #{stdout_str}, Errors: #{stderr_str}"
    error(message, ignore_errors: ignore_errors)
  end
  { stdout: stdout_str, stderr: stderr_str, status: status }
end

def log(message)
  puts message
  File.open('/var/log/deploy.log', 'a') { |f| f.print "#{Time.now.utc} #{message}\n" }
end

def error(message, ignore_errors: false)
  log(message)
  abort(message) unless ignore_errors
end

main
