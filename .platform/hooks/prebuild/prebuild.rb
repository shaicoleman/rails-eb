#!/opt/elasticbeanstalk/lib/ruby/bin/ruby
# frozen_string_literal: true

require_relative './build_utils'

def main
  init
  enable_eatmydata
  enable_swap
  nonblocking_dev_random
  install_repos
  install_yum_packages
  cleanup_yum_packages
  install_zstd
  extract_app
  copy_files
  create_symlinks
  run_handlers
  change_webapp_shell
  enable_linger
  check_ruby_version
  upgrade_bundler
  upgrade_reline
  finish
end

FILES = [
  { source: 'bin/webapp', target: '/home/ec2-user/bin/webapp' },
  { source: 'chrony/chrony.conf', target: '/etc/chrony.conf', handler: 'restart_chronyd' },
  { source: 'elasticbeanstalk/checkforraketask.rb', target: '/opt/elasticbeanstalk/config/private/checkforraketask.rb' },
  { source: 'htop/htoprc', target: '/root/.config/htop/htoprc' },
  { source: 'journald/journald.conf', target: '/etc/systemd/journald.conf', handler: 'restart_journald' },
  { source: 'motd/10eb-banner', target: '/etc/update-motd.d/10eb-banner', no_backup: true },
  { source: 'profile.d/profile.sh', target: '/etc/profile.d/profile.sh' },
  { source: 'profile.d/prompt.sh', target: '/etc/profile.d/prompt.sh' },
  { source: 'profile.d/rbenv.sh', target: '/etc/profile.d/rbenv.sh' },
  { source: 'ssh/sshd_config', target: '/etc/ssh/sshd_config', handler: 'restart_sshd' },
  { source: 'ssh/sshd_service.conf', target: '/etc/systemd/system/sshd.service.d/sshd_service.conf', handler: 'restart_sshd' },
  { source: 'sysctl.d/local.conf', target: '/etc/sysctl.d/local.conf', handler: 'reload_sysctl' },

  { source: 'nginx/elasticbeanstalk-nginx-ruby-upstream.conf', target: '/etc/nginx/conf.d/elasticbeanstalk-nginx-ruby-upstream.conf', handler: 'test_nginx_config' },
  { source: 'nginx/gzip.conf', target: '/etc/nginx/conf.d/gzip.conf', handler: 'test_nginx_config' },
  { source: 'nginx/healthd.conf', target: '/etc/nginx/conf.d/elasticbeanstalk/healthd.conf', handler: 'test_nginx_config' },
  { source: 'nginx/healthd_logformat.conf', target: '/etc/nginx/conf.d/healthd_logformat.conf', handler: 'test_nginx_config' },
  { source: 'nginx/nginx.conf.erb', target: '/etc/nginx/nginx.conf', template: 'erb', handler: 'test_nginx_config' },
  { source: 'nginx/webapp.conf', target: '/etc/nginx/conf.d/elasticbeanstalk/webapp.conf', handler: 'test_nginx_config' },
  { source: 'puma/pumaconf.rb', target: '/opt/elasticbeanstalk/config/private/pumaconf.rb' }
]

SYMLINKS = [
  { source: '/etc/nginx', target: '.platform/nginx' }, # Prevent /etc/nginx from being overwritten  
  { source: '/usr/bin/vim', target: '/usr/local/bin/vi' }
]

AMAZON_LINUX_EXTRAS = %w[postgresql10]

YUM_PACKAGES = [
  { package: 'htop', creates: '/usr/bin/htop' },
  { package: 'iotop', creates: '/usr/sbin/iotop' },
  { package: 'mc', creates: '/usr/bin/mc' },
  { package: 'nodejs', creates: '/usr/bin/node' },
  { package: 'postgresql', creates: '/usr/share/doc/postgresql-10.*' },
  { package: 'strace', creates: '/usr/bin/strace' },
  { package: 'yarn', creates: '/usr/bin/yarn' },
  # { package: 'ds_agent', creates: '/opt/ds_agent/ds_agent',
  #   url: 'https://ca-downloads.s3-eu-west-1.amazonaws.com/deepsecurity/Agent-PGPCore-amzn2-20.0.0-2204.x86_64.rpm' },
  { package: 'file-libs', creates: '/usr/share/doc/file-libs-5.39',
    url: 'https://ca-downloads.s3-eu-west-1.amazonaws.com/file/file-libs-5.39-5.amzn2.x86_64.rpm' },
  { package: 'file', creates: '/usr/share/doc/file-5.39',
    url: 'https://ca-downloads.s3-eu-west-1.amazonaws.com/file/file-5.39-5.amzn2.x86_64.rpm' },
  { package: 'libsodium', creates: '/usr/lib64/libsodium.so.*',
    url: 'https://ca-downloads.s3-eu-west-1.amazonaws.com/libsodium/libsodium-1.0.18-1.el7.x86_64.rpm' },
  { package: 'ncdu', creates: '/usr/bin/ncdu',
    url: 'https://ca-downloads.s3-eu-west-1.amazonaws.com/ncdu/ncdu-1.15.1-1.el7.x86_64.rpm' },
  { package: 'ripgrep', creates: '/usr/bin/rg',
    url: 'https://ca-downloads.s3-eu-west-1.amazonaws.com/ripgrep/ripgrep-12.1.1-1.el7.x86_64.rpm' },
  { package: 'tmux', creates: '/usr/bin/tmux',
    url: 'https://ca-downloads.s3-eu-west-1.amazonaws.com/tmux/tmux-3.1c-2.amzn2.x86_64.rpm' },
  # { package: 'wkhtmltox', creates: '/usr/local/bin/wkhtmltopdf',
  #   url: 'https://ca-downloads.s3-eu-west-1.amazonaws.com/wkhtmltopdf/wkhtmltox-0.12.6-1.amazonlinux2.x86_64.rpm' }
]

YUM_CLEANUP = [
  { package: 'hunspell*', removes: '/bin/hunspell' },
  { package: 'ImageMagick*', removes: '/usr/bin/Magick-config' },
  { package: 'iptables*', removes: '/sbin/iptables' },
  { package: 'mariadb*', removes: '/usr/bin/mysql' },
  { package: 'postgres*-9*', removes: '/usr/share/doc/postgresql-9*' },
  { package: 'rng-tools', removes: '/usr/sbin/rngd' },
  { package: 'tcsh', removes: '/bin/tcsh' }
]

def enable_swap
  return if File.read('/proc/swaps').include?('/swapfile')

  total_ram_kb = `cat /proc/meminfo`.match(/^MemTotal:\s+(\d+) kB/)&.captures.first&.to_i
  swap_size_kb = [total_ram_kb * 0.25, 1048576].max.ceil
  run("fallocate -l #{swap_size_kb}K /swapfile; mkswap -f /swapfile; chmod 600 /swapfile; swapon /swapfile")
end

# Not necessary for kernel >= 5.6
def nonblocking_dev_random
  return if File.stat('/dev/random').rdev_minor == 9

  run('rm /dev/random; sudo mknod -m 666 /dev/random c 1 9')
end

def enable_eatmydata
  return if File.exist?('/usr/bin/eatmydata')

  # Only installed and enabled on first run
  url = 'https://ca-downloads.s3-eu-west-1.amazonaws.com/eatmydata/libeatmydata-0.1-00.21.el7.centos.x86_64.rpm'
  run("rpm -U #{url}")
  log('Enabling eatmydata')
  ENV['LD_PRELOAD'] = '/usr/lib64/libeatmydata.so'
end

def install_repos
  enable_amazon_linux_extras
  install_nodejs_repo
  install_yarn_repo
end

def install_zstd
  return if File.exist?('/usr/local/bin/zstd')

  `curl -sSL https://ca-downloads.s3-eu-west-1.amazonaws.com/zstd/zstd-1.5.0.tar.xz | tar -xJC /`
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

def upgrade_reline
  minimum_version = '0.2.5'
  installed_version = `ruby -e "require 'reline'; print Reline::VERSION"`
  return if Gem::Version.new(installed_version) >= Gem::Version.new(minimum_version)

  run('gem install reline')
end

def extract_app
  return unless File.exist?('.build/app.tar.zst')

  run('zstdcat .build/app.tar.zst | tar -x')
  FileUtils.rm_f('.build/app.tar.zst')
end

def enable_amazon_linux_extras
  extras = File.read('/etc/yum.repos.d/amzn2-extras.repo')
  to_enable = AMAZON_LINUX_EXTRAS.reject { |item| extras.match?(/\[amzn2extra-#{item}\]\nenabled = 1/) }
  return if to_enable.empty?

  run("amazon-linux-extras enable #{to_enable.join(' ')}")
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

  run("yum -y autoremove #{to_cleanup.join(' ')}")
end

def install_yum_packages
  to_install = YUM_PACKAGES.reject { |item| Dir.glob(item[:creates]).any? } \
                           .map { |item| item[:url] || item[:package] }
  return if to_install.empty?

  run("yum -y install #{to_install.join(' ')}")
end

def autoremove_yum_packages
  run('yum -y autoremove') if File.exist?('/usr/bin/pango-list')
end

def reload_sysctl
  run('sysctl -p /etc/sysctl.d/local.conf', ignore_errors: true)
end

def restart_sshd
  run('systemctl daemon-reload; sshd -t && systemctl restart sshd')
end

def restart_journald
  FileUtils.mkdir_p('/var/log/journal', mode: 02755)
  run('systemctl restart systemd-journald')
end

def restart_chronyd
  run('systemctl restart chronyd')
end

def test_nginx_config
  run('nginx -t')
end

def change_webapp_shell
  return if File.read('/etc/passwd').match?(%r{^webapp:.*:/bin/bash$})

  run('usermod --shell /bin/bash webapp')
end

# Don't kill tmux/screen sessions
def enable_linger
  return if File.exist?('/var/lib/systemd/linger/webapp')

  run('loginctl enable-linger ec2-user webapp')
end

main
