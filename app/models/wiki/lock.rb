
# Wiki::Lock objects are protected by optimistic locking
# this means that if two users load the same Wiki::Lock
# the first one will be able to save it, the second one will get a StaleObject exception on save

# Note: Wiki::Lock has no concept of section hierarchy!
# this means that if :document is locked for user 'blue'
# a subsection of :document will appear open to a different user
# Always use Wiki::Locking methods for manipulating wiki locks
# since those methods take section hierarchy into account
class Wiki::Lock < ApplicationRecord
  belongs_to :wiki

  validates_presence_of :wiki

  LOCKING_PERIOD = 120.minutes

  #   locks => {:document => {:by => user_id, :expires_at => Time},
  #                       'section-name' => {:by => user_id, :expires_at => Time}, ...}
  #
  # accessor for +locks+ attribute. The default value is +{}+
  serialize :locks, Hash
  serialize_default :locks, {}

  after_find :update_expired_locks!

  def all_sections
    wiki.all_sections
  end

  def lock!(section, user)
    locks[section] = { by: user.id, expires_at: Time.now.utc + LOCKING_PERIOD }
    update_attributes!(locks: locks)
  end

  #
  # removes a lock from one or more sections, saving the result immediately
  #
  def unlock!(sections)
    [sections].flatten.each do |section|
      if section == :document
        locks.clear
      else
        locks.delete(section)
      end
    end
    update_attributes!(locks: locks)
  end

  def sections_open_for(user)
    all_sections - sections_locked_for(user)
  end

  #
  # returns list of sections that the user may NOT edit
  #
  def sections_locked_for(user)
    locked_for_user = []
    locks.each do |section, lock|
      locked_for_user << section unless user.real? && lock[:by] == user.id
    end

    # don't show any sections as locked if they don't exist
    locked_for_user & all_sections
  end

  # returns the first section locked by user, or nil
  def section_locked_by(user)
    section, lock = locks.find { |_section, lock| lock[:by] == user.id }
    section
  end

  # returns true if the section is locked by user
  def locked_by?(section, user)
    locks[section] && locks[section][:by] == user.id
  end

  protected

  # this should be called every time Wiki::Lock is loaded from db
  # so that we may never see any expired locks
  def update_expired_locks!
    current_time = Time.now.utc

    self.locks = locks.reject do |section, lock|
      # reject if past due and time is used OR if the section doesn't exist
      (lock[:expires_at] and lock[:expires_at] < current_time) or !all_sections.include?(section)
    end
  end

  # def [](key)
  #   locks[key]
  # end
  #
  # def []=(key, val)
  #   locks[key] = val
  # end
end
