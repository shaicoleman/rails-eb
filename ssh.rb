#!/usr/bin/env ruby

require 'json'
require 'yaml'
# require 'byebug'
# require 'ap'
require 'time'
require 'action_view'

include ActionView::Helpers::DateHelper

def main
  config
  get_env_name
  get_instances
  show_instances
  choose_instance
  ec2_instance_connect
  ssh
end

def config
  @instance_os_user = 'shai.coleman'
  @public_key_file = File.expand_path('~/.ssh/id_rsa.pub')
  @private_key_file = File.expand_path('~/.ssh/id_rsa')
end

def get_env_name
  git_branch = `git rev-parse --abbrev-ref HEAD`.strip
  eb_config = YAML.safe_load(File.read('.elasticbeanstalk/config.yml'), aliases: true)
  @env_name = ARGV[0] ||
              eb_config.dig('branch-defaults', git_branch, 'environment') ||
              eb_config.dig('branch-defaults', 'default', 'environment')
end

def get_instances
  cmd = "aws ec2 describe-instances " \
        "--filters 'Name=tag:elasticbeanstalk:environment-name,Values=#{@env_name}' " \
        "--query 'Reservations[].Instances[]'"
  result = JSON.parse(`#{cmd}`)
  @instances = result.map do |instance|
    {
      instance_id: instance['InstanceId'],
      availability_zone: instance.dig('Placement', 'AvailabilityZone'),
      image_id: instance['ImageId'],
      instance_type: instance['InstanceType'],
      launch_template_version: Integer(instance.dig('Tags').find { |tag| tag['Key'] == 'aws:ec2launchtemplate:version' }&.dig('Value')),
      launch_time: Time.parse(instance['LaunchTime']),
      private_ip: instance['PrivateIpAddress'],
      public_ip: instance['PublicIpAddress'],
      state: instance.dig('State', 'Name'),
    }
  end.sort_by { |i| i[:launch_time] }.reverse
end

def show_instances
  @instances.each.with_index(1) do |inst, i|
    puts "#{i}) #{inst[:instance_id]}, #{inst[:state]}, launched #{time_ago_in_words(inst[:launch_time])} ago, #{inst[:public_ip]}"
  end
end

def choose_instance
  @instance = @instances.first
end

def ec2_instance_connect
  cmd = "aws ec2-instance-connect send-ssh-public-key " \
        "--instance-id #{@instance[:instance_id]} " \
        "--availability-zone #{@instance[:availability_zone]} " \
        "--instance-os-user #{@instance_os_user} " \
        "--ssh-public-key file://#{@public_key_file}"
  result = JSON.parse(`#{cmd}`)
end

def ssh
  puts "ssh -o IdentitiesOnly=yes -i #{@private_key_file} #{@instance_os_user}@#{@instance[:public_ip]}"
end

main



# aws ec2-instance-connect send-ssh-public-key \
#     --instance-id i-0896fc126d9300906 \
#     --availability-zone eu-west-1a \
#     --instance-os-user shai.coleman \
#     --ssh-public-key file:///home/shai/.ssh/id_rsa.pub

# ssh -o "IdentitiesOnly=yes" -i /home/shai/.ssh/id_rsa shai.coleman@54.170.187.101
