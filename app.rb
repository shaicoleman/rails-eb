class App < Sinatra::Base
    set :public_folder, 'public'
    set :default_content_type, 'application/json'

    get "/" do
      hostname = "#{`hostname`.chomp}"
      build_info = File.read('./_meta/build-info.txt').scan(/^([^:]+): (.*)$/).to_h
      now = "#{Time.now.utc}"
      JSON.dump(now: now, hostname: hostname, build_info: build_info)
    end
end
