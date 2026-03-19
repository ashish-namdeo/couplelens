class MemoriesController < ApplicationController
  before_action :authenticate_user!

  def index
    @memories = current_user.memories.recent
  end

  def new
    @memory = current_user.memories.new
  end

  def create
    @memory = current_user.memories.new(memory_params)

    if @memory.save
      redirect_to memories_path, notice: 'Memory saved! 💝'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @memory = current_user.memories.find(params[:id])
    @memory.destroy
    redirect_to memories_path, notice: 'Memory removed.'
  end

  private

  def memory_params
    params.require(:memory).permit(:title, :description, :memory_date, :memory_type, :photo)
  end
end
