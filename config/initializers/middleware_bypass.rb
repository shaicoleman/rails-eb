# frozen_string_literal: true

class MiddlewareBypass
  def initialize(app)
    @app = app
  end

  def call(env)
    return [200, {}, ['OK']] if env['PATH_INFO'] == '/healthcheck'

    @app.call(env)
  end
end

Rails.application.middleware.insert 0, MiddlewareBypass
