require 'sinatra/base'
require 'logger'

class WorkerSample < Sinatra::Base
    set :logging, true

    set :public_folder, 'public'

    @@logger = Logger.new('/tmp/sample-app.log')

    get "/" do
        redirect '/index.html'
    end

    post '/' do
        msg_id = request.env["HTTP_X_AWS_SQSD_MSGID"]
        data = request.body.read
        @@logger.info "Received message: #{data}"
    end

    post '/scheduled' do
        task_name = request.env["HTTP_X_AWS_SQSD_TASKNAME"]
        scheduling_time = request.env["HTTP_X_AWS_SQSD_SCHEDULED_AT"]
        @@logger.info "Received task: #{task_name} scheduled at #{scheduling_time}"
    end
end
