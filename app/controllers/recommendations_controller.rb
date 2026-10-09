class RecommendationsController < ApplicationController
  def new
  end

  def create
    @category = params[:category]
    @amount = params[:amount]
    @merchant = params[:merchant]
    @product = params[:product]

    if @category.present? && @amount.present?
      if Current.user.can_get_recommendation?
        agent = RagAgent.new(Current.user, @category, @amount, merchant: @merchant, product: @product)
        @recommendation, tokens = agent.call
        @citations = agent.citations
        save_recommendation(Current.user, @category, @amount, @recommendation, tokens)
      else
        @error = "You have reached your weekly recommendation limit (#{Current.user.weekly_recommendations_limit}). Upgrade to Premium for unlimited access!"
      end
    else
      @error = "Please provide both category and amount."
    end

    respond_to do |format|
      format.turbo_stream
      format.html { render :new, status: :unprocessable_entity }
    end
  rescue StandardError => e
    @error = "An error occurred: #{e.message}"
    respond_to do |format|
      format.turbo_stream
      format.html { render :new, status: :unprocessable_entity }
    end
  end

  private

  def save_recommendation(user, category, amount, recommendation, tokens = {})
    # Approximate pricing for Haiku caching (adjust based on real prices)
    # Claude 3.5 Haiku: Input $1.00/1M, Cached Input $0.10/1M -> Savings: $0.90 per 1M cached tokens
    savings = (tokens[:cached_tokens].to_i / 1_000_000.0) * 0.90

    recommendation_record = Recommendation.new(
      user: user,
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
