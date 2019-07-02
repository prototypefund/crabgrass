GroupArchiveJob = Struct.new(:group, :user) do

  def perform()
    Group::Archive.create!(group: group, created_by_id: user.id)
  end

end
