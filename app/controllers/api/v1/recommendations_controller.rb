module Api
  module V1
    class RecommendationsController < ApplicationController
      skip_before_action :verify_authenticity_token
      
      # require_authentication is already registered by ApplicationController,
      # but we need to override the unauthorized behavior for an API
      def require_authentication
        token_auth = authenticate_with_http_token do |token, options|
          Current.user = User.find_by(api_token: token)
        end

        unless token_auth || resume_session
          render json: { error: "Unauthorized" }, status: :unauthorized
        end
      end

      def create
        amount = params[:amount].to_f
        category = params[:category].to_s
        coupon_codes = params[:coupon_codes] || []

        recommendations, tokens = Timeout.timeout(15) do
          RagAgent.new(
            Current.user, 
            category, 
            amount,
            coupon_codes: coupon_codes
          ).call
        end

        if recommendations.is_a?(Array)
          best_card = recommendations.find { |r| r["recommended"].to_s == "true" } || recommendations.first
          save_recommendation(category, amount, recommendations, tokens)
          render json: best_card, status: :ok
        else
          render json: recommendations, status: :ok
        end
      rescue Timeout::Error
        render json: { error: "Request timed out while analyzing recommendations. Please try again." }, status: :gateway_timeout
      rescue => e
        Rails.logger.error("API Error: #{e.message}\n#{e.backtrace.join("\n")}")
        render json: { error: e.message }, status: :unprocessable_content
      end

      private

      def save_recommendation(category, amount, recommendation, tokens = {})
        # Approximate pricing for Haiku caching (adjust based on real prices)
        # Claude 3.5 Haiku: Input $1.00/1M, Cached Input $0.10/1M -> Savings: $0.90 per 1M cached tokens
        savings = (tokens[:cached_tokens].to_i / 1_000_000.0) * 0.90

        recommendation_record = Recommendation.new(
          category: category,
          amount: amount,
          data: recommendation,
          input_tokens: tokens[:input_tokens],
          output_tokens: tokens[:output_tokens],
          cached_tokens: tokens[:cached_tokens],
          cost_savings: savings
        )
        if recommendation_record.save
          Rails.logger.info("Recommendation successfully saved - Category: #{category}, Amount: #{amount}, Cost Savings: $#{savings.round(5)}")
        else
          Rails.logger.error("Recommendation failed to save: #{recommendation_record.errors.full_messages}")
        end
      end
    end
  end
end
