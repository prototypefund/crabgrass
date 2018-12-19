#
# A request to create archive of group content as single page HTML.
#
#   recipient: the group to be exported
# requestable: the same group
#  created_by: person in group who want their group to be destroyed
#

class RequestToCreateGroupArchiveSinglepage < RequestToCreateGroupArchive

  def after_approval
    # TODO: this should be tracked! But how to use the tracking
    # mechanism outside of a controller?
    Delayed::Job.enqueue GroupArchiveJob.new(group, created_by, singlepage = true)
  end

end
