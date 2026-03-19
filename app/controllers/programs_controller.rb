class ProgramsController < ApplicationController
  before_action :authenticate_user!

  def index
    @programs = Program.published.includes(:lessons)
    @my_programs = current_user.user_programs.includes(:program)
  end

  def show
    @program = Program.published.find(params[:id])
    @lessons = @program.lessons.ordered
    @user_program = current_user.user_programs.find_by(program: @program)
  end

  def enroll
    @program = Program.published.find(params[:id])
    user_program = current_user.user_programs.find_or_create_by(program: @program) do |up|
      up.status = :enrolled
      up.current_lesson = 0
    end
    redirect_to program_path(@program), notice: 'You are now enrolled!'
  end
end
