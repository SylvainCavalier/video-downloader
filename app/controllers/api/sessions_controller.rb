module Api
  class SessionsController < BaseController
    skip_before_action :require_authentication, only: :me

    def me
      if user_signed_in?
        render json: { id: current_user.id, email: current_user.email }
      else
        render json: { user: nil }, status: :unauthorized
      end
    end
  end
end
