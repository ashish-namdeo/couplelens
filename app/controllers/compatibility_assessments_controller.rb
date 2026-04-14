class CompatibilityAssessmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_assessment, only: [:show, :destroy]

  def index
    @assessments = current_user.compatibility_assessments.order(created_at: :desc)
  end

  def show; end

  def new
    @assessment = current_user.compatibility_assessments.new
  end

  def create
    @assessment = current_user.compatibility_assessments.new(assessment_params)
    @assessment.status = :in_progress

    begin
      gemini = GeminiService.new
      result = gemini.assess_compatibility(answers: {
        partner_name: params[:compatibility_assessment][:partner_name],
        relationship_duration: params[:relationship_duration],
        financial_approach: params[:financial_approach],
        spending_habits: params[:spending_habits],
        social_preference: params[:social_preference],
        conflict_style: params[:conflict_style],
        children_preference: params[:children_preference],
        family_involvement: params[:family_involvement],
        strengths_text: params[:strengths_text],
        concerns_text: params[:concerns_text]
      }, language: params[:language] || 'english')

      @assessment.financial_score = result[:financial_score]
      @assessment.lifestyle_score = result[:lifestyle_score]
      @assessment.parenting_score = result[:parenting_score]
      @assessment.overall_score = @assessment.overall_calculated_score
      @assessment.strengths = result[:strengths]
      @assessment.risk_areas = result[:risk_areas]
      @assessment.full_report = result[:full_report]
      @assessment.status = :completed

      if @assessment.save
        notice_msg = params[:language] == 'hindi' ? 'AI संगतता मूल्यांकन पूरा हुआ!' : 'AI compatibility assessment completed!'
        redirect_to @assessment, notice: notice_msg
      else
        render :new, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error("Compatibility assessment error: #{e.message}")
      error_msg = params[:language] == 'hindi' ? 'AI विश्लेषण विफल। कृपया पुनः प्रयास करें।' : "AI analysis failed. Please try again."
      @assessment.errors.add(:base, error_msg)
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @assessment.destroy
    redirect_to compatibility_assessments_path, notice: 'Assessment deleted.'
  end

  private

  def set_assessment
    @assessment = current_user.compatibility_assessments.find_by!(slug: params[:id])
  end

  def assessment_params
    params.require(:compatibility_assessment).permit(:partner_name)
  end
end
