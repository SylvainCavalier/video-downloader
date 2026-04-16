module Api
  class BaseController < ApplicationController
    respond_to :json

    before_action :require_authentication

    rescue_from ActiveRecord::RecordNotFound, with: :not_found
    rescue_from ActiveRecord::RecordInvalid do |e|
      render json: { errors: e.record.errors.full_messages }, status: :unprocessable_content
    end

    private

    def require_authentication
      return if user_signed_in?

      render json: { error: "Authentication required" }, status: :unauthorized
    end

    def user_not_authorized
      render json: { error: "Not authorized" }, status: :forbidden
    end

    def not_found
      render json: { error: "Not found" }, status: :not_found
    end
  end
end
