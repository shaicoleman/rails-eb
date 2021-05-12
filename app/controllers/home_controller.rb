class HomeController < ApplicationController
  def index
    instance_id = `ec2-metadata --instance-id || true`.chomp.presence || `hostname`.chomp
    build_info = File.read('./.build/build-info.txt').scan(/^([^:]+): (.*)$/).to_h
    now = "#{Time.now.utc}"
    render json: { now: now, instance_id: instance_id, build_info: build_info }
  end
end
