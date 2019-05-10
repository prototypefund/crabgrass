# The page history lists actions related to a given page.
# Therefore we need to keep track of the changes. We store them in
# PageHistory.
#
# This module makes creating the records from the controller easy.
#
# If you follow the conventions all you need to do is add a after_action for
# the actions you want to track:
#
# class Groups::GroupsController < ...
#   track_actions :create, :destroy
# ...
#
# This will have the same effect as an after filter for track_action:
#   after_action :track_action, only: [:create, :destroy]
#
# track_action will call Action.track(:create_group, options). It will include
# the following default arguments if the corresponding variables are set:
#   group: @group,
#   user: @user || current_user,
#   page: @page,
#   current_user: current_user
#
# Please make sure that Action.track can deal with the event symbol you
# hand it. It has a lookup table for the records to create for a
# given symbol.
#
# If you want to customize the arguments you can overwrite track_action.
# The options given will overwrite the defaults.
#
# class Groups::StructuresController < ...
#   :track_actions :create, :destroy
#   ...
#   def track_action
#     super("#{action}_group", group: @committee)
#   end

module Common::Tracking::Action
  extend ActiveSupport::Concern

  def track_action(event = nil, options = {})
    if options.blank? && event.is_a?(Hash)
      options = event
      event = nil
    end
    event ||= "#{action_string}_#{controller_name.singularize}"
    event_options = options.reverse_merge current_user: current_user,
                                          group: @group,
                                          user: @user || current_user,
                                          page: @page
    ::Tracking::Action.track event.to_sym, event_options
  end

  module ClassMethods
    def track_actions(*actions)
      options = actions.extract_options!
      after_action :track_action, options.merge(only: actions)
    end
  end
end
