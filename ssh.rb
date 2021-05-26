#!/usr/bin/env ruby

require 'json'
require 'yaml'
require 'byebug'
# require 'ap'
require 'time'
require 'action_view'

include ActionView::Helpers::DateHelper

def main
  config
  get_env_name
  get_username
  get_instances
  show_instances
  choose_instance
  wait_for_instance
  ec2_instance_connect
  ssh
end

def config
  @public_key_file = File.expand_path('~/.ssh/id_rsa.pub')
  @private_key_file = File.expand_path('~/.ssh/id_rsa')
  @eb_config = YAML.safe_load(File.read('.elasticbeanstalk/config.yml'), aliases: true)
end

def get_env_name
  git_branch = `git rev-parse --abbrev-ref HEAD`.strip
  @env_name = ARGV[0] ||
              @eb_config.dig('branch-defaults', git_branch, 'environment') ||
              @eb_config.dig('branch-defaults', 'default', 'environment')
end

def get_username
  @username = @eb_config.dig('ssh', 'username')

  abort "Please add to your .elasticbeanstalk/config.yml:\nssh:\n  user_name: joe.bloggs" if @username.to_s.empty?
end

def get_instances
  cmd = "aws ec2 describe-instances " \
        "--filters 'Name=tag:elasticbeanstalk:environment-name,Values=#{@env_name}' " \
        "--query 'Reservations[].Instances[]'"
  result = JSON.parse(`#{cmd}`)
  all_instances = result.map do |instance|
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
  end
  @instances = all_instances.select { |i| i[:state] == 'pending' || i[:state] == 'running' } \
                            .sort_by { |i| i[:launch_time] }.reverse
end

def show_instances
  puts "Select an instance to ssh into" if @instances.size > 1

  @instances.each.with_index(1) do |inst, i|
    instance_count = "#{i}) " if @instances.one?
    puts "#{i}) #{inst[:instance_id]}, #{inst[:state]}, launched #{time_ago_in_words(inst[:launch_time])} ago, #{inst[:public_ip]}"
  end
end

def choose_instance
  abort 'No valid instance' unless @instances.any?

  if @instances.one?
    @instance = @instances.first
    return
  end

  loop do
    print "(default is 1): "
    instance_str = gets&.strip
    exit unless instance_str

    if instance_str == ''
      @instance = @instances.first
      return
    end

    instance_num = Integer(instance_str, exception: false)
    unless instance_num >= 1 && instance_num <= @instances.size
      puts "Sorry, that is not a valid choice. Please choose a number between 1 and #{@instances.size}."
    end

    @instance = @instances[instance_num - 1]
    return if @instance
  end
end

def wait_for_instance
  0.step do |count|
    break if Time.now >= @instance[:launch_time] + 30

    puts "Waiting for instance to launch..." if count == 0
    sleep 1
  end
end

def ec2_instance_connect
  cmd = "aws ec2-instance-connect send-ssh-public-key " \
        "--instance-id #{@instance[:instance_id]} " \
        "--availability-zone #{@instance[:availability_zone]} " \
        "--instance-os-user #{@username} " \
        "--ssh-public-key file://#{@public_key_file}"
  result = JSON.parse(`#{cmd}`)
end

def ssh
  cmd = "ssh -o GlobalKnownHostsFile=/dev/null " \
        "-o UserKnownHostsFile=/dev/null " \
        "-o StrictHostKeyChecking=no " \
        "-o IdentitiesOnly=yes " \
        "-i #{@private_key_file} " \
        "#{@username}@#{@instance[:public_ip]}"
  puts cmd
  exec(cmd)
end

main
