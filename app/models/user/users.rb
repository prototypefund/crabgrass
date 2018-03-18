#
#
# Everything to do with user <> user relationships should be here.
#
# "relationships" is the join table:
#    user has many users through relationships
#
module User::Users
  def self.included(base)
    base.send :include, InstanceMethods

    base.instance_eval do
      serialize_as IntArray, :friend_id_cache, :foe_id_cache

      initialized_by :update_contacts_cache,
                     :friend_id_cache, :foe_id_cache

      ##
      ## PEERS
      ##

      def self.peers_of(user)
        where('users.id in (?)', user.peer_id_cache)
      end

      ##
      ## USER'S STATUS / PUBLIC WALL
      ##

      has_one :wall_discussion, as: :commentable, dependent: :destroy, class_name: 'Discussion'

      before_destroy :save_relationships
      attr_reader :peers_before_destroy, :contacts_before_destroy

      ##
      ## RELATIONSHIPS
      ##

      has_many :relationships,
               class_name: 'User::Relationship',
               dependent: :destroy

      has_many :friendships,
               -> { where type: 'Friendship' },
               class_name: 'User::Relationship'

      has_many :discussions,
               -> { order 'discussions.replied_at DESC' },
               through: :relationships

      has_many :contacts, through: :relationships

      has_many :friends, through: :friendships, source: :contact do
        def most_active(options = {})
          options[:limit] ||= 13
          max_visit_count = select('MAX(relationships.total_visits) as id').first.id || 1
          select = 'users.*, ' + quote_sql([MOST_ACTIVE_SELECT, 2.week.ago.to_i, 2.week.seconds.to_i, max_visit_count])
          limit(options[:limit]).select(select).order('last_visit_weight + total_visits_weight DESC')
        end
      end

      # same result as user.friends, but makes use of cache.
      def self.friends_of(user)
        where('users.id in (?)', user.friend_ids)
      end

      def self.friends_or_peers_of(user)
        where('users.id in (?)', user.friend_ids + user.peer_ids)
      end

      # neither friends nor peers
      # used for autocomplete when we preloaded the friends and peers
      def self.strangers_to(user)
        where 'users.id NOT IN (?)',
              user.friend_ids + user.peer_ids + [user.id]
      end

      ##
      ## CACHE
      ##

      serialize_as IntArray, :friend_id_cache, :foe_id_cache, :peer_id_cache
      initialized_by :update_contacts_cache, :friend_id_cache, :foe_id_cache
      initialized_by :update_membership_cache, :peer_id_cache
    end
  end

  module InstanceMethods
    def peers
      User.peers_of(self).readonly
    end

    ##
    ## STATUS / PUBLIC WALL
    ##

    # returns the users current status by returning their latest status_posts.body
    def current_status
      @current_status ||= wall_discussion.posts
                                         .where('type' => 'StatusPost')
                                         .order('created_at DESC')
                                         .first.try.body || ''
    end

    ##
    ## RELATIONSHIPS
    ##

    # Creates a relationship between self and other_user. This should be the ONLY
    # way that contacts are created.
    #
    # If type is :friend or "Friendship", then the relationship from self to other
    # user will be one of friendship.
    #
    # This method can be used to either add a new relationship or to update an
    # an existing one
    #
    def add_contact!(other_user, type = nil)
      type = 'Friendship' if type == :friend

      relationship = other_user.relationships.with(self).first_or_initialize
      relationship.type = type
      relationship.save!

      relationship = relationships.with(other_user).first_or_initialize
      relationship.type = type
      relationship.save!

      relationships.reset
      contacts.reset
      friends.reset
      update_contacts_cache

      other_user.relationships.reset
      other_user.contacts.reset
      other_user.friends.reset
      other_user.update_contacts_cache

      relationship
    end

    # this should be the ONLY way contacts are deleted
    def remove_contact!(other_user)
      if relationships.with(other_user).exists?
        contacts.delete(other_user)
        update_contacts_cache
      end
      if other_user.relationships.with(self).exists?
        other_user.contacts.delete(self)
        other_user.update_contacts_cache
      end
    end

    # ensure a relationship between this and the other user exists
    # add a new post to the private discussion shared between this and the other_user.
    #
    # +in_reply_to+ is an optional argument for the post that this new post
    # is replying to.
    #
    # currently, this is not stored, but used to generate a more informative
    # notification on the user's wall.
    #
    def send_message_to!(other_user, body, in_reply_to = nil)
      relationship = relationships.with(other_user).first || add_contact!(other_user)
      relationship.send_message(body, in_reply_to)
    end

    def stranger_to?(user)
      !peer_of?(user) and !contact_of?(user)
    end

    def peer_of?(user)
      id = user.instance_of?(Integer) ? user : user.id
      peer_id_cache.include?(id)
    end

    def friend_of?(user)
      id = user.instance_of?(Integer) ? user : user.id
      friend_id_cache.include?(id)
    end
    alias contact_of? friend_of?

    def relationship_to(user)
      relationships_to(user).first
    end

    def relationships_to(user)
      return :stranger unless user

      @relationships_to_user_cache ||= {}
      @relationships_to_user_cache[user.login] ||= get_relationships_to(user)
      @relationships_to_user_cache[user.login].dup
    end

    def get_relationships_to(user)
      ret = []
      ret << :friend   if friend_of?(user)
      ret << :peer     if peer_of?(user)
      ret << :stranger
      ret
    end

    ##
    ## PERMISSIONS
    ##

    def may_show_status_to?(user)
      return true if user == self
      return true if friend_of?(user) or peer_of?(user)
      false
    end
  end # InstanceMethods

  private

  MOST_ACTIVE_SELECT = '((UNIX_TIMESTAMP(relationships.visited_at) - ?) / ?) AS last_visit_weight, (relationships.total_visits / ?) as total_visits_weight'.freeze

  def save_relationships
    @peers_before_destroy = peers.dup
    @contacts_before_destroy = contacts.dup
  end
end
