class WorkshopsController < ApplicationController
  before_action :authenticate_user!

  def index
    @workshops = Workshop.upcoming_events
  end

  def show
    @workshop = Workshop.find(params[:id])
  end

  def register
    @workshop = Workshop.find(params[:id])

    if @workshop.sold_out?
      redirect_to @workshop, alert: 'Sorry, this workshop is sold out.'
      return
    end

    registration = current_user.workshop_registrations.find_or_create_by(workshop: @workshop) do |wr|
      wr.amount_paid = @workshop.price
      wr.status = :registered
    end

    if registration.persisted?
      @workshop.increment!(:spots_taken)
      redirect_to workshops_path, notice: 'Successfully registered!'
    else
      redirect_to @workshop, alert: 'Could not register. Please try again.'
    end
  end
end
