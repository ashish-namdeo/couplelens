class ExpensesController < ApplicationController
  before_action :authenticate_user!

  def index
    @expenses = current_user.expenses.recent
    @this_month_total = current_user.expenses.this_month.sum(:amount)
    @shared_total = current_user.expenses.this_month.shared_expenses.sum(:amount)
    @categories_data = current_user.expenses.this_month.group(:category).sum(:amount)
    @expense = Expense.new
  end

  def create
    @expense = current_user.expenses.new(expense_params)

    if @expense.save
      redirect_to expenses_path, notice: 'Expense added!'
    else
      @expenses = current_user.expenses.recent
      @this_month_total = current_user.expenses.this_month.sum(:amount)
      @shared_total = current_user.expenses.this_month.shared_expenses.sum(:amount)
      @categories_data = current_user.expenses.this_month.group(:category).sum(:amount)
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @expense = current_user.expenses.find(params[:id])
    @expense.destroy
    redirect_to expenses_path, notice: 'Expense removed.'
  end

  private

  def expense_params
    params.require(:expense).permit(:category, :amount, :description, :expense_date, :shared)
  end
end
