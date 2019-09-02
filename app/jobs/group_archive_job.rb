GroupArchiveJob = Struct.new(:group, :user, :language) do

  def enqueue(job)
    Group::Archive.create!(group: group, created_by_id: user.id)
    I18n.locale = language
  end

  def perform
    # although we should only have one archive per group,
    # we make sure to get the newest
    archive = Group::Archive.order(created_at: :desc).
      find_by(group: group, created_by_id: user.id)
    archive.process if archive
  end

end
