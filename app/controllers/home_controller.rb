class HomeController < ApplicationController
  def index
    render json: { now: "#{Time.now.utc}" }
  end
end
