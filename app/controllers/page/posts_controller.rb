class Page::PostsController < ApplicationController
  include Common::Tracking::Action

  include_controllers 'common/posts'

  permissions 'pages'
  permissions 'posts'
  helper 'page/post'

  prepend_before_filter :fetch_data
  before_filter :login_required, except: :show
  before_filter :authorization_required
  guard :may_ALIAS_post?
  guard show: :may_show_page?
  guard index: :may_show_page?

  track_actions :create, :update, :destroy

  # js action to rerender the posts
  def index
    @posts = @page.posts(pagination_params)
    @post = Post.new
  end

  def show
    respond_to do |format|
      format.js   { render 'common/posts/show' }
      format.html { redirect_to page_url(@page) + "#post-#{@post.id}" }
    end
  end

  def create
    if @post = @page.add_post(current_user, post_params)
      respond_to do |format|
        format.js   { redirect_to action: :index }
        format.html { redirect_to page_url(@page) + "#post-#{@post.id}" }
      end
    end
  end

  protected

  def fetch_data
    @page = Page.find(params[:page_id])
    if params[:id]
      @post = @page.discussion.posts.includes(:discussion).find(params[:id])
      raise PermissionDenied.new unless @post
    end
  end

  def post_params
    params.require(:post).permit(:body)
  end

  def track_action
    super item: @post
  end
end
