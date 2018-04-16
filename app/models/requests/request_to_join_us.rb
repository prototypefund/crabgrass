#
# Otherwise known as a group membership invitation
#
# recipient: person who may be added to group
# requestable: the group
# created_by: person who sent the invite
#
class RequestToJoinUs < MembershipRequest
  validates_format_of :requestable_type, with: /\AGroup\z/
  validates_format_of :recipient_type, with: /\AUser\z/

  validate :no_membership_yet, on: :create

  def group
    requestable
  end

  def user
    recipient
  end

  def may_create?(user)
    user.may?(:admin, group)
  end

  def may_approve?(user)
    user == recipient
  end

  def may_destroy?(user)
    user.may?(:admin, group)
  end

  def may_view?(user)
    may_create?(user) or may_approve?(user)
  end

  def description
    [:request_to_join_us_description, { user: user_span(recipient), group: group_span(group) }]
  end

  def short_description
    [:request_to_join_short, { user: user_span(recipient), group: group_span(group) }]
  end

  def icon_entity
    recipient
  end

  protected

  def no_membership_yet
    if user.memberships.where(group_id: group).exists?
      errors.add(:base, I18n.t(:membership_exists_error, member: recipient.name))
    end
  end
end
