class HealthcheckController < ActionController::Metal
  def index
    self.response_body = 'OK'
  end
end
