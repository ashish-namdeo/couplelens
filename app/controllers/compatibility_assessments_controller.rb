class CompatibilityAssessmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_assessment, only: [:show]

  def index
    @assessments = current_user.compatibility_assessments.order(created_at: :desc)
  end

  def show; end

  def new
    @assessment = current_user.compatibility_assessments.new
  end

  def create
    @assessment = current_user.compatibility_assessments.new(assessment_params)
    @assessment.status = :completed

    # Generate assessment scores (simulated AI analysis)
    @assessment.financial_score = rand(55.0..95.0).round(1)
    @assessment.lifestyle_score = rand(60.0..98.0).round(1)
    @assessment.parenting_score = rand(50.0..92.0).round(1)
    @assessment.overall_score = @assessment.overall_calculated_score

    @assessment.strengths = generate_strengths
    @assessment.risk_areas = generate_risk_areas
    @assessment.full_report = generate_full_report(@assessment)

    if @assessment.save
      redirect_to @assessment, notice: 'Compatibility assessment completed!'
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_assessment
    @assessment = current_user.compatibility_assessments.find(params[:id])
  end

  def assessment_params
    params.require(:compatibility_assessment).permit(:partner_name)
  end

  def generate_strengths
    strengths = [
      "Strong emotional connection and mutual empathy",
      "Aligned long-term life goals and vision",
      "Excellent conflict resolution skills",
      "Shared values around family and community",
      "Compatible communication styles",
      "Mutual respect for individual growth",
      "Strong physical and emotional intimacy",
      "Aligned financial priorities and habits"
    ]
    strengths.sample(4).join("\n• ")
  end

  def generate_risk_areas
    risks = [
      "Different approaches to financial planning",
      "Varying expectations around work-life balance",
      "Potential differences in parenting philosophies",
      "Communication gaps during high-stress periods",
      "Different love languages may need attention",
      "Boundaries with extended family members"
    ]
    risks.sample(3).join("\n• ")
  end

  def generate_full_report(assessment)
    <<~REPORT
      # Compatibility Assessment Report

      ## Overall Compatibility: #{assessment.overall_score}%

      ## Financial Compatibility: #{assessment.financial_score}%
      Your financial mindsets show #{assessment.financial_score > 75 ? 'strong alignment' : 'some areas for growth'}. Focus on establishing shared financial goals and regular money conversations.

      ## Lifestyle Compatibility: #{assessment.lifestyle_score}%
      Your lifestyle preferences are #{assessment.lifestyle_score > 75 ? 'well-matched' : 'diverse but complementable'}. Embrace both shared activities and individual interests.

      ## Parenting Philosophy: #{assessment.parenting_score}%
      Your parenting perspectives #{assessment.parenting_score > 75 ? 'align well' : 'offer complementary strengths'}. Regular discussions about parenting values will strengthen your partnership.

      ## Strengths
      • #{assessment.strengths}

      ## Areas for Growth
      • #{assessment.risk_areas}

      ## Recommendations
      1. Schedule weekly check-ins to discuss relationship goals
      2. Take a couples communication workshop
      3. Practice daily appreciation rituals
      4. Consider pre-marital counseling for deeper exploration
    REPORT
  end
end
