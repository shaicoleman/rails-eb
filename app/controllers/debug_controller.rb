class DebugController < ApplicationController
  def trigger_error
    raise 'Test error'
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

  def instance_id
    instance_id = `ec2-metadata --instance-id || true`.chomp.presence
    render json: { instance_id: instance_id }
  end

  def build_info
    build_info = File.read('./.build/build-info.txt').scan(/^([^:]+): (.*)$/).to_h        
    render json: { build_info: build_info }
  end
end
