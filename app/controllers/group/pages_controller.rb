class Group::PagesController < Group::BaseController
  skip_before_filter :login_required

  include_controllers 'common/page_search'

  def index
    authorize @group, :show?
    @path  = apply_path_modifiers(parsed_path)
    @pages = Page.paginate_by_path(@path, options_for_group(@group), pagination_params)
    render template: 'common/pages/search/index', locals: { hide_owner: true }
  end

  protected

  def setup_navigation(nav)
    nav[:local] = [
      { active: false, visible: policy(@group).edit?, html: { partial: 'common/pages/search/create' } },
      { active: true,  visible: true, html: { partial: 'common/pages/search/controls_active' } },
      { active: false, visible: true, html: { partial: 'common/pages/search/controls_possible' } }
    ]
    nav
  end

  #
  # the common page search code relies on this being defined
  #
  def page_search_path(*args)
    group_pages_path(*args)
  end

  #
  # hide filters for the my_pages section
  #
  def show_filter?(filter)
    filter.section != :my_pages
  end
end
