module Api
  module V1
    class BaseController < ActionController::API
      private

      def render_success(data = {}, status: :ok)
        render json: { status: "ok" }.merge(data), status: status
      end

      def render_error(message, status: :bad_request)
        render json: { status: "error", message: message }, status: status
      end
    end
  end
end
