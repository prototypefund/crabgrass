GroupArchiveJob = Struct.new(:group, :user) do

  def enqueue(job)
    Group::Archive.create!(group: group, created_by_id: user.id)
  end

  def perform()
    # although we should only have one archive per group, we make sure
    # to get the newest
    archive = Group::Archive.order('created_at DESC').find_by(group: group, created_by_id: user.id)
    archive.process if archive
  end

end
