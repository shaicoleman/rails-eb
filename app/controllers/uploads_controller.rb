class UploadsController < ApplicationController
  def new
  end

  def create
    @size = params[:file].size
  end
end
