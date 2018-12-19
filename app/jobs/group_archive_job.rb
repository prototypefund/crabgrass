GroupArchiveJob = Struct.new(:group, :user, :singlepage) do

  def perform()
    Group::Archive.find_or_create(group: group, user: user, singlepage: singlepage)
  end

end
