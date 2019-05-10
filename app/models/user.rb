class User < ApplicationRecord

  ##
  ## CORE EXTENSIONS
  ##

  include User::Cache      # cached user data (should come first)
  include User::Users      # user <--> user
  include User::Groups     # user <--> groups
  include User::Pages      # user <--> pages
  include User::Tags       # user <--> tags
  include User::Authenticated
  include User::LegacyPasswords

  acts_as_castle

  ##
  ## VALIDATIONS
  ##

  include Crabgrass::Validations
  validates_handle :login, unless: :ghost?

  before_validation :validates_receive_notifications

  def validates_receive_notifications
    self.receive_notifications = nil unless %w[Single Digest].include?(receive_notifications)
  end

  validates :email,
            email_format: { allow_blank: true },
            presence: { if: :should_validate_email }

  def should_validate_email
    return false if ghost?
    Conf.require_user_email
  end

  ##
  ## NAMED SCOPES
  ##

  def self.recent
    order('users.created_at DESC').where('users.created_at > ?', 2.weeks.ago)
  end

  # this is a little mysql magic to get what we want:
  # We want to sort by display_name.presence || login
  # if the display_name is NULL
  #   CONCAT is null and we get login from COALESCE
  # if the display_name is ""
  #   CONCAT gives us the login
  # if the display name is present
  #   CONCAT gives display_name + login which will sort by display name basically.
  # alphabetized and (optional) limited to +letter+

  def self.alphabetic_order
    order <<-EOSQL
      LOWER(
        COALESCE(
          CONCAT(users.display_name, users.login),
          users.login
        )
      ) ASC
    EOSQL
  end

  def self.alphabetized(letter = nil)
    if letter == '#'
      conditions = ['login REGEXP ?', '^[^a-z]']
    elsif !letter.blank?
      conditions = ['login LIKE ?', "#{letter}%"]
    end
    where(conditions).alphabetic_order
  end

  def self.named_like(filter)
    where 'users.login LIKE ? OR users.display_name LIKE ?',
          filter, filter
  end

  ##
  ## USER IDENTITY
  ##

  def cache_key
    "user/#{id}-#{version}"
  end

  belongs_to :avatar, dependent: :destroy

  validates_format_of :login, with: /\A[a-z0-9]+([-_\.]?[a-z0-9]+){1,17}\z/
  before_validation :clean_names

  def clean_names
    write_attribute(:login, (read_attribute(:login) || '').downcase)

    t_name = read_attribute(:display_name)
    write_attribute(:display_name, t_name.gsub(/[&<>]/, '')) if t_name
  end

  before_save :display_name_update

  def display_name_update
    if display_name_changed?
      increment :version
      Group.increment_version(group_ids)
    end
  end

  after_save :update_name
  def update_name
    if login_changed? and !login_was.nil?
      pages_owned.update_all(owner_name: login)
      pages_created.update_all(created_by_login: login)
      pages_updated.update_all(updated_by_login: login)
      Wiki.clear_all_html(self)
    end
  end

  after_destroy :kill_avatar
  def kill_avatar
    avatar.destroy if avatar
  end

  # the user's custom display name, could be anything.
  def display_name
    read_attribute('display_name').presence || login
  end

  # the user's handle, in same namespace as group name,
  # must be url safe.
  def name
    login
  end

  # displays both display_name and name
  def both_names
    if read_attribute('display_name').present? && read_attribute('display_name') != name
      format('%s (%s)', display_name, name)
    else
      name
    end
  end
  alias to_s both_names # used for indexing

  def cut_name
    name[0..20]
  end

  def to_param
    login
  end

  def path
    "/#{login}"
  end

  def banner_style
    # @style ||= Style.new(:color => "#E2F0C0", :background_color => "#6E901B")
    @style ||= Style.new(color: '#eef', background_color: '#1B5790')
  end

  def online?
    last_seen_at > 10.minutes.ago if last_seen_at
  end

  def time_zone
    read_attribute(:time_zone).presence || Time.zone_default
  end

  #
  # returns this user, as a ghost.
  #
  # Note that we load the user from scratch so the attributes are separate
  # This way you can modify the ghost without touching the original user.
  #
  def ghostify!
    update_attribute :type, 'Ghost'
    User.find(id)
  end

  # overwritten in user_ghost
  def ghost?
    false
  end

  ##
  ## PROFILE
  ##

  has_many :profiles, as: 'entity', dependent: :destroy, extend: ProfileMethods

  has_one :public_profile,
          -> { where stranger: true },
          as: 'entity',
          class_name: 'Profile'

  has_one :private_profile,
          -> { where friend: true },
          as: 'entity',
          class_name: 'Profile'

  has_one :pgp_key, dependent: :destroy

  accepts_nested_attributes_for :pgp_key, allow_destroy: true, reject_if: :all_blank

  # returns true if the user wants to receive
  # and email when someone sends them a page notification
  # message.
  def wants_notification_email?
    email.present?
  end

  ##
  ## ASSOCIATED DATA
  ##

  has_many :task_participations,
           class_name: 'Task::Participation',
           dependent: :destroy
  has_many :tasks, through: :task_participations do
    def pending
      where('completed_at IS NULL')
    end

    def completed
      where('completed_at IS NOT NULL')
    end
  end

  has_many :posts, dependent: :destroy

  has_many :stars, dependent: :destroy, inverse_of: :user

  has_many :notices, dependent: :destroy

  after_destroy :destroy_requests
  def destroy_requests
    Request.destroy_for_user(self)
  end

  # returns the rating object that this user created for a rateable
  def rating_for(rateable)
    rateable.ratings.by_user(self).first
  end

  # returns true if this user rated the rateable
  def rated?(rateable)
    return false unless rateable
    rating_for(rateable) ? true : false
  end

  ##
  ## PERMISSIONS
  ##

  # keyring_code used by castle_gates and pathfinder
  def keyring_code
    format('%04d', "1#{id}")
  end

  # all codes of the entities I have access to:
  def access_codes
    codes = [0] # public
    return codes if new_record?
    codes << keyring_code.to_i # me
    codes.concat friend_id_cache.map { |id| "7#{id}".to_i } # friends
    codes.concat all_group_id_cache.map { |id| "8#{id}".to_i } # peers
    codes.concat peer_id_cache.map { |id| "9#{id}".to_i } # groups
  end

  # Returns true if self has the specified level of access on the protected thing.
  # Thing may be anything that defines the method:
  #
  #    has_access!(access_sym, user)
  #
  # Currently, this includes Page and Group.
  #
  # this method gets called a lot (ie current_user.may?(:admin,@page)) so
  # we in-memory cache the result.
  #
  def may?(perm, protected_thing)
    may!(perm, protected_thing)
  rescue PermissionDenied
    false
  end

  def may!(perm, protected_thing)
    return false if protected_thing.nil?
    return true if protected_thing.new_record?
    # users may perform all actions on themselves
    return true if self == protected_thing
    key = protected_thing.to_s
    protected_thing.has_access!(perm, self)
  end
end

