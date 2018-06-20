#
# A request to create a council.
#
#   recipient: the group to get the council
# requestable: the same group
#  created_by: person in group who wants to create the council
#

class RequestToCreateCouncil < Request
  validates_format_of :recipient_type,   with: /\AGroup\z/
  validates_format_of :requestable_type, with: /\AGroup\z/

  alias_attr :group, :recipient

  def self.existing(options)
    pending.to_group(options[:group]).first
  end

  def may_create?(user)
    user.may?(:admin, group) and
      user.longterm_member_of?(group)
  end

  def may_approve?(user)
    user.may?(:admin, group) and
      user.id != created_by_id and
      user.longterm_member_of?(group)
  end

  alias may_view? may_create?
  alias may_destroy? may_create?

  def after_approval
    council = Group::Council.new
    council.name = :council.t
    council.created_by = created_by
    council.save!
    group.add_committee!(council)
    council.add_user!(created_by)
    council.add_user!(approved_by) unless approved_by.member_of?(council)
  end

  def description
    [:request_to_create_council_description, {
      group: group_span(group),
      group_type: group.group_type.downcase,
      user: user_span(created_by)
    }]
  end

  def short_description
    [:request_to_create_council_short, {
      group: group_span(group),
      group_type: group.group_type.downcase,
      user: user_span(created_by)
    }]
  end
end
