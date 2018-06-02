class RateManyPossiblesController < Page::BaseController
  before_filter :fetch_poll

  # ajax only, returns nothing
  # for this to work, there must be a <ul id='sort_list_xxx'> element
  # and it must be declared sortable like this:
  # <%= sortable_element 'sort_list_xxx', .... %>
  def sort
    return unless params[:sort_list].present?
    ids = params[:sort_list]
    @poll.possibles.each do |possible|
      position = ids.index(possible.id.to_s)
      possible.update_attribute('position', position + 1) if position
    end
    render nothing: true
  end

  def create
    @possible = @poll.possibles.create possible_params
    if @poll.valid? and @possible.valid?
      current_user.updated(@page)
      @page.unresolve
    else
      @poll.possibles.delete(@possible)
      warning @possible unless @possible.valid?
      warning @poll unless @poll.valid?
      redirect_to page_url(@page, action: 'show')
    end
  end

  def destroy
    return unless @poll
    possible = @poll.possibles.find(params[:id])
    possible.destroy
    current_user.updated @page
    redirect_to page_url(@page, action: 'show')
  end

  def update
    new_value = params[:value].to_i
    @possible = @poll.possibles.find(params[:id])
    @poll.votes.by_user(current_user).for_possible(@possible).delete_all
    @poll.votes.create! user: current_user, value: new_value, possible: @possible
    current_user.updated(@page, resolved: true)
  end

  protected

  def possible_params
    params.require(:poll_possible).permit(:name, :description)
  end

  def fetch_poll
    authorize @page, :edit?
    @poll = @page.data
  end
end
