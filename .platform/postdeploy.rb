#!/opt/elasticbeanstalk/lib/ruby/bin/ruby
# frozen_string_literal: true

require_relative './build_utils'

FILES = [
  { source: 'amazon-cloudwatch-agent/config.json.erb', target: '/opt/aws/amazon-cloudwatch-agent/bin/config.json', template: 'erb' }
]

def main
  init
  copy_files
  restart_cloudwatch_agent
  chown_env_file_to_webapp
  update_motd
  finish  
end

def chown_env_file_to_webapp
  FileUtils.chown('root', 'webapp', '/opt/elasticbeanstalk/deployment/env')
  FileUtils.chmod(0440, '/opt/elasticbeanstalk/deployment/env')
end

def update_motd
  run_background('update-motd')
end

def restart_cloudwatch_agent
  cmd = <<~EOT
    cd /opt/aws/amazon-cloudwatch-agent &&
    rm -rf etc/{env-config.json,log-config.json,beanstalk.json,amazon-cloudwatch-agent.d/file_beanstalk.json,amazon-cloudwatch-agent.toml} &&
    bin/amazon-cloudwatch-agent-ctl -a fetch-config -s -m ec2 -c file:bin/config.json &&
    systemctl enable amazon-cloudwatch-agent &&
    systemctl restart amazon-cloudwatch-agent --no-block
  EOT
  run_background(cmd)
end

main
