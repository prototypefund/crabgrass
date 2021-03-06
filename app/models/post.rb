class Post < ApplicationRecord
  ##
  ## ASSOCIATIONS
  ##

  acts_as_rateable
  belongs_to :discussion    # counter_cache is handled manually, see Discussion.post_created.
  belongs_to :user
  belongs_to :page_terms    # if this is on a page we set page_terms so we can use path_finder

  has_many :stars, as: :starred, dependent: :delete_all
  has_many :notices, as: :noticable, dependent: :delete_all

  after_create :post_created
  after_destroy :post_destroyed

  ##
  ## POST ACCESS CONTROL
  ##

  def self.policy_class
    PostPolicy
  end

  ##
  ## FINDERS
  ##

  acts_as_path_findable

  def self.visible
    where deleted_at: nil
  end

  def self.by_created_at
    order('created_at DESC')
  end

  def self.private_messages(user)
    where discussion_id: user.discussions.pluck(:id)
  end

  def self.last_in_discussion
    where <<-EOSQL
      posts.created_at = (
        SELECT MAX(other_posts.created_at) FROM posts AS other_posts
        WHERE other_posts.discussion_id = posts.discussion_id
        AND other_posts.deleted_at <=> posts.deleted_at
      )
    EOSQL
  end

  ##
  ## ATTIBUTES
  ##

  format_attribute :body
  validates_presence_of :user, :body
  validate :in_reply_to_matches_recipient
  validate :no_spam

  alias created_by user

  attr_accessor :in_reply_to # the post this post was in reply to.

  attr_accessor :recipient # for private posts, a tmp var to store who

  ##
  ## METHODS
  ##

  #
  # this is like a normal create, except that it optionally accepts multiple arguments:
  #
  # page -- the page that this post belongs to (optional)
  # user -- the user creating the post (optional)
  # discussion -- the discussion holding this post (optional)
  # attributes -- a hash of attributes to fill the new post.
  #
  # You should have at least page or discussion.
  #
  # for example:
  #
  #   Post.create! @page, current_user, params[:post]
  #
  def self.create!(*args, &block)
    user = nil
    page = nil
    discussion = nil
    attributes = {}
    args.each do |arg|
      user       = arg if arg.is_a? User
      page       = arg if arg.is_a? Page
      attributes = arg if arg.is_a? Hash
      discussion = arg if arg.is_a? Discussion
    end
    if page
      page.create_discussion unless page.discussion
      attributes[:discussion] = page.discussion
      attributes[:page_terms_id] = page.page_terms.id
    end
    attributes[:discussion] = discussion if discussion
    attributes[:user] = user if user
    post = Post.new(attributes, &block)
    post.save!
    post
  end

  # used for default context, if present, to set for any embedded links
  def owner_name
    discussion.page.owner_name if discussion.page
  end

  # used for indexing
  def to_s
    "#{user} #{body}"
  end

  def starred_by?(user)
    stars.exists? user_id: user
  end

  # These are currently only used from moderation mod.
  #
  # We implement a similar interface as for pages to ease things there.

  def flow=(value)
    value.to_i == FLOW[:deleted] ? delete : undelete
  end

  def delete
    update_attribute :deleted_at, Time.now
    post_destroyed(true)
  end

  def deleted?
    !!deleted_at
  end

  def deleted_changed?
    deleted_at_changed?
  end

  def undelete
    update_attribute :deleted_at, nil
    post_created
  end

  # this should be able to be handled in the subclasses, but sometimes
  # when you create a new post, the subclass is not set yet.
  def public?
    %w[Post PublicPost StatusPost].include?(read_attribute(:type))
  end

  def private?
    read_attribute(:type) == 'PrivatePost'
  end

  def default?
    false
  end

  def lite_html
    GreenCloth.new(body, 'page', [:lite_mode]).to_html
  end

  def body_id
    "post_#{id}_body"
  end

  def with_link?
    format_body
    /<(\/*)a\s([^>]*?)>/ === body_html
  end

  protected

  def post_created
    discussion.post_created(self)
  end

  def post_destroyed(force_decrement = false)
    # don't decrement if post is already marked deleted.
    decrement = force_decrement || deleted_at.nil?
    discussion.post_destroyed(self, decrement) if discussion
  end

  #
  # VALIDATIONS
  #

  def in_reply_to_matches_recipient
    return if in_reply_to.blank?
    if in_reply_to.user_id != recipient.id
      errors.add :in_reply_to,
                 "Ugh. The user and the post you are replying to don't match."
    end
  end

  def no_spam
    page = discussion.try.page
    return unless page.try.public? && with_link?
    return if user.may?(:view, page)
    Rails.logger.info 'Detected possible SPAM:'
    Rails.logger.info body
    errors.add :body, I18n.t(:spam_comment_detected)
  end
end
