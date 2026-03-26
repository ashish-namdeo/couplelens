class HealthDashboardController < ApplicationController
  before_action :authenticate_user!

  def show
    @health_metrics = current_user.health_metrics.recent
    @communication_scores = current_user.health_metrics.by_type('communication').order(:recorded_at)
    @trust_scores = current_user.health_metrics.by_type('trust').order(:recorded_at)
    @conflict_scores = current_user.health_metrics.by_type('conflict_resolution').order(:recorded_at)
    @intimacy_scores = current_user.health_metrics.by_type('intimacy').order(:recorded_at)
    @goals_scores = current_user.health_metrics.by_type('shared_goals').order(:recorded_at)

    @overall_score = current_user.health_metrics.average(:score)&.round(1) || 0
    @metric_averages = HealthMetric::METRIC_TYPES.map do |type|
      {
        type: type.titleize,
        score: current_user.health_metrics.by_type(type).average(:score)&.round(1) || 0
      }
    end

    @last_calculated = current_user.health_metrics.order(recorded_at: :desc).first&.recorded_at
  end

  def calculate
    calculator = HealthScoreCalculatorService.new(current_user)
    result = calculator.calculate!

    if result
      redirect_to health_path, notice: "Health scores updated successfully based on your recent activity!"
    else
      redirect_to health_path, alert: "Not enough activity data yet. Keep using CoupleLens features to generate your health scores."
    end
  end
end
