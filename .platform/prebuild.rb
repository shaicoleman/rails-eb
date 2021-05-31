#!/opt/elasticbeanstalk/lib/ruby/bin/ruby
# frozen_string_literal: true

require_relative './build_utils'

def main
  init
  create_users
  configure_users
  delete_ec2_user
  enable_eatmydata
  enable_swap
  nonblocking_dev_random
  install_repos
  install_yum_packages
  cleanup_yum_packages
  install_zstd
  extract_app
  extract_home
  check_ruby_version
  copy_files
  create_symlinks
  run_handlers
  finish
end

FILES = [
  { source: 'chrony/chrony.conf', target: '/etc/chrony.conf', handler: 'restart_chronyd' },
  { source: 'elasticbeanstalk/checkforraketask.rb', target: '/opt/elasticbeanstalk/config/private/checkforraketask.rb' },
  { source: 'htop/htoprc', target: '/root/.config/htop/htoprc' },
  { source: 'journald/journald.conf', target: '/etc/systemd/journald.conf', handler: 'restart_journald' },
  { source: 'motd/10eb-banner', target: '/etc/update-motd.d/10eb-banner', no_backup: true },
  { source: 'profile.d/profile.sh.erb', target: '/etc/profile.d/profile.sh', template: 'erb'  },
  { source: 'profile.d/prompt.sh', target: '/etc/profile.d/prompt.sh' },
  { source: 'profile.d/rbenv.sh', target: '/etc/profile.d/rbenv.sh' },
  { source: 'ssh/sshd_config', target: '/etc/ssh/sshd_config', handler: 'restart_sshd' },
  { source: 'ssh/sshd_service.conf', target: '/etc/systemd/system/sshd.service.d/sshd_service.conf', handler: 'restart_sshd' },
  { source: 'sysctl.d/local.conf', target: '/etc/sysctl.d/local.conf', handler: 'reload_sysctl' },
  { source: 'ruby/gemrc', target: "/opt/rubies/ruby-#{ruby_version}/etc/gemrc" },

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

USERS = [
  { username: 'shai.coleman' }
]

AMAZON_LINUX_EXTRAS = %w[postgresql10]

YUM_PACKAGES = [
  # Server monitoring/logging/security
  { package: 'amazon-cloudwatch-agent', creates: '/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent' },
  { package: 'amazon-ssm-agent', creates: '/usr/bin/amazon-ssm-agent' },
  { package: 'ec2-instance-connect', creates: '/opt/aws/bin/eic_run_authorized_keys' },
  # { package: 'ds_agent', creates: '/opt/ds_agent/ds_agent', url: 'https://ca-downloads.s3-eu-west-1.amazonaws.com/deepsecurity/Agent-PGPCore-amzn2-20.0.0-2204.x86_64.rpm' },

  # App dependencies
  { package: 'file', creates: '/usr/share/doc/file-5.39', url: 'https://ca-downloads.s3-eu-west-1.amazonaws.com/file/file-5.39-5.amzn2.x86_64.rpm' },
  { package: 'file-libs', creates: '/usr/share/doc/file-libs-5.39', url: 'https://ca-downloads.s3-eu-west-1.amazonaws.com/file/file-libs-5.39-5.amzn2.x86_64.rpm' },
  { package: 'libsodium', creates: '/usr/lib64/libsodium.so.*', url: 'https://ca-downloads.s3-eu-west-1.amazonaws.com/libsodium/libsodium-1.0.18-1.el7.x86_64.rpm' },
  { package: 'nodejs', creates: '/usr/bin/node' },
  { package: 'postgresql', creates: '/usr/share/doc/postgresql-10.*' },
  # { package: 'wkhtmltox', creates: '/usr/local/bin/wkhtmltopdf', url: 'https://ca-downloads.s3-eu-west-1.amazonaws.com/wkhtmltopdf/wkhtmltox-0.12.6-1.amazonlinux2.x86_64.rpm' },
  { package: 'yarn', creates: '/usr/bin/yarn' },

  # Utilities
  { package: 'htop', creates: '/usr/bin/htop' },
  { package: 'iotop', creates: '/usr/sbin/iotop' },
  { package: 'mc', creates: '/usr/bin/mc' },
  { package: 'ncdu', creates: '/usr/bin/ncdu', url: 'https://ca-downloads.s3-eu-west-1.amazonaws.com/ncdu/ncdu-1.15.1-1.el7.x86_64.rpm' },
  { package: 'ripgrep', creates: '/usr/bin/rg', url: 'https://ca-downloads.s3-eu-west-1.amazonaws.com/ripgrep/ripgrep-12.1.1-1.el7.x86_64.rpm' },
  { package: 'strace', creates: '/usr/bin/strace' },
  { package: 'tmux', creates: '/usr/bin/tmux', url: 'https://ca-downloads.s3-eu-west-1.amazonaws.com/tmux/tmux-3.1c-2.amzn2.x86_64.rpm' }
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
  unless expected_ruby_version == ruby_version
    log("Warning: .ruby-version mismatch - Expected: #{expected_ruby_version}, Current: #{ruby_version}. Renamed")
    FileUtils.mv('.ruby-version', '.ruby-version-mismatch')
  end
end

def extract_app
  return unless File.exist?('.build/app.tar.zst')

  run('zstdcat .build/app.tar.zst | tar -x')
  FileUtils.rm_f('.build/app.tar.zst')
end

def extract_home
  return unless File.exist?('.build/home.tar.zst')

  usernames = USERS.map { |user| user[:username] } + ['webapp']
  usernames.each do |username|
    FileUtils.rm_f("/home/#{username}/.local")
    run("zstdcat .build/home.tar.zst | tar -xC /home/#{username}")
    FileUtils.chown_R(username, 'webapp', "/home/#{username}/.local")
  end
  FileUtils.rm_f('.build/home.tar.zst')
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

  run('curl -sSL https://rpm.nodesource.com/setup_14.x | bash -')
end

def install_yarn_repo
  return if File.exist?('/etc/yum.repos.d/yarn.repo')

  run('curl -sSL https://dl.yarnpkg.com/rpm/yarn.repo > /etc/yum.repos.d/yarn.repo')
end

def cleanup_yum_packages
  to_cleanup = YUM_CLEANUP.select { |item| Dir.glob(item[:removes]).any? } \
                          .map { |item| item[:package] }
  return if to_cleanup.empty?

  run_background("yum -y autoremove #{to_cleanup.join(' ')}")
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
  run('systemctl daemon-reload; sshd -t && systemctl restart sshd --no-block')
end

def restart_journald
  FileUtils.mkdir_p('/var/log/journal', mode: 02755)
  run('systemctl restart systemd-journald --no-block')
end

def restart_chronyd
  run('systemctl restart chronyd --no-block')
end

def test_nginx_config
  run('nginx -t')
end

def create_users
  unless `getent group sudo`.start_with?('sudo:')
    run('groupadd sudo')
  end
  copy_file({ source: 'ruby/.gemrc', target: '/etc/skel/.gemrc' })

  USERS.each do |user|
    unless File.exist?("/home/#{user[:username]}")
      run("adduser #{user[:username]} --gid webapp --groups sudo")
    end
  end
end

def configure_users
  # Don't kill tmux/screen sessions
  linger_users = USERS.reject { |user| File.exist?("/var/lib/systemd/linger/#{user[:username]}") } \
                      .map { |user| user[:username] }
  run("loginctl enable-linger #{linger_users.join(' ')}") if linger_users.any?

  copy_file({ source: 'sudoers.d/sudo', target: '/etc/sudoers.d/sudo' })

  unless File.read('/etc/passwd').match?(%r{^webapp:.*:/bin/bash$})
    run('usermod --shell /sbin/nologin webapp')
  end
end

def delete_ec2_user
  `userdel --remove --force ec2-user` if File.exist?('/home/ec2-user')
end

main
