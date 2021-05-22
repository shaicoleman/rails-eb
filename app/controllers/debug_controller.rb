class DebugController < ApplicationController
  def trigger_error
    raise 'Test error'
  end

  def stress
    seconds = params[:seconds].presence&.to_f || 1.0
    stopwatch = Stopwatch.new
    x = []
    while stopwatch.elapsed < seconds do
      x.unshift(SecureRandom.alphanumeric(64))
      x.sort!
    end
    render json: { sleep: seconds }
  end

  def debug_sleep
    seconds = params[:seconds].presence&.to_f || 1.0
    sleep seconds
    render json: { sleep: seconds }
  end

  def debug_request
    headers = self.request.env.filter_map do |k, v|
      next unless k.match?(/^HTTP_/) && !k.match?(/^HTTP_(VERSION|X_FORWARD|X_AMZN|X_REAL_IP|COOKIE)/)
      [k.remove(/^HTTP_/).titleize.gsub(/\s+/, '-'), v]
    end.sort_by { |x| x.first }.to_h

    render json: { method: request.method, url: request.url, headers: headers,
                   params: params.except(:controller, :action, :debug),
                   body: request.body }
  end

  def env
    render json: { env: ENV.keys.sort }
  end

  def instance_id
    instance_id = `ec2-metadata --instance-id || true`.match(/(i-[0-9a-z]+)/)&.captures&.first
    render json: { instance_id: instance_id }
  end

  def build_info
    build_info = File.read('./.build/build-info.txt').scan(/^([^:]+): (.*)$/).to_h        
    render json: { build_info: build_info }
  end
end
