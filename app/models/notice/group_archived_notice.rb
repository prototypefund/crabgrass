class Notice::GroupArchivedNotice < Notice

  alias_attr :group, :noticable

  def button_text
  end

  def display_label
    :archive.t
  end

  def display_body
    display_attr(:body).html_safe
  end

  def redirect_object
    group.try.name || data[:group]
  end

  protected

  before_create :encode_data
  def encode_data
    self.data = {title: :notification, body: [:group_archive_created, {group: ('<group>%s</group>' % group.name), user: user}]}
  end

end
