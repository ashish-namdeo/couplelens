class TherapistRegistrationsController < ApplicationController
  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    @user.role = :couple_member # Start as couple_member, upgraded on approval

    if @user.save
      # Create therapist application automatically
      @user.create_therapist_application!(
        full_name: "#{@user.first_name} #{@user.last_name}",
        email: params[:therapist_email] || @user.email,
        specialization: params[:specialization],
        bio: params[:bio],
        certifications: params[:certifications],
        years_experience: params[:years_experience],
        hourly_rate: params[:hourly_rate],
        status: :submitted
      )

      sign_in(@user)
      redirect_to root_path, notice: 'Account created! Your therapist application has been submitted for review. You will be notified once approved.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:first_name, :last_name, :email, :password, :password_confirmation, :profile_image)
  end
end
