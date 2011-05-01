# 
# Routes:
#
#  update:  page_attributes_path      /pages/:page_id/attributes
#

class Pages::AttributesController < Pages::SidebarController

  before_filter :login_required

  def update
    if params[:public]
      @page.public = params[:public]
      @page.updated_by = current_user
      @page.save!
      render(:update) {|page| page.replace 'public_li', public_line}
    end
  end

end
