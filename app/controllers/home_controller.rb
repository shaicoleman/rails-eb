class HomeController < ApplicationController
  def index
    hostname = "#{`hostname`.chomp}"
    build_info = File.read('./_meta/build-info.txt').scan(/^([^:]+): (.*)$/).to_h
    now = "#{Time.now.utc}"
    render json: { now: now, hostname: hostname, build_info: build_info }
  end
end
