GroupArchiveJob = Struct.new(:group, :user) do

  # TODO: handle failure

  def perform()
    Group::Archive.new(group: group, user: user).process
  end

end
