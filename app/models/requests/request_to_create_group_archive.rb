#
# A request to create archive of group content.
#
#   recipient: the group to be exported
# requestable: the same group
#  created_by: person in group who want their group to be destroyed
#

class RequestToCreateGroupArchive < Request
  validates_format_of :recipient_type,   with: /\AGroup\z/
  validates_format_of :requestable_type, with: /\AGroup\z/

  alias_attr :group, :recipient

  # once the group has been deleted we do not require it anymore.
  def recipient_required?
    !approved?
  end
  alias requestable_required? recipient_required?

  def self.already_exists?(options)
    pending.from_group(options[:group]).exists?
  end

  def may_create?(user)
    user.may?(:admin, group)
  end

  def may_approve?(user)
    user.may?(:admin, group) and user.id != created_by_id
  end

  def no_duplicate; end

  alias may_view? may_create?
  alias may_destroy? may_create?

  def after_approval
    Delayed::Job.enqueue GroupArchiveJob.new(group, created_by)
  end

  def event
    :create_group_archive
  end

  def event_attrs
    { groupname: group.name, recipient: created_by, archived_by: approved_by }
  end

  def description
    [:request_to_create_group_archive_description, description_args]
  end

  def short_description
    [:request_to_create_group_archive_short, description_args]
  end

  def description_args
    { group:      group_span,
      group_type: group.group_type.downcase,
      user:       user_span(created_by) }
  end

  def icon_entity
    group
  end

end
