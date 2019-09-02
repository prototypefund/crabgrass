define_navigation do
  ##
  ## HOME

  # disabled for now
  global_section :home do
    label   { :home.t }
    visible { false } # !logged_in? || controller?(:account, :session, :root) }
    url     '/'
    active  { controller?(:account, :session, :root) }
  end

  ##
  ## ME
  ##

  global_section :me do
    label   { :me.t }
    url     { logged_in? ? me_home_path : '/' }
    active  { context?(:me) || controller?(:account, :session, :root) }
    html    partial: '/layouts/global/nav/me_menu'

    context_section :create_page do
      label   { :create_thing.t(thing: :page.t) }
      url     { new_page_path }
      active  false
      icon    :plus
      visible { @drop_down_menu }
    end

    context_section :pages do
      label  { :pages.t }
      url    { me_pages_path }
      active { page_controller? }
      icon   :page_white_copy
    end

    context_section :messages do
      label  { :messages.t }
      url    { me_discussions_path }
      active { controller?('me/discussions', 'me/posts') }
      icon   :page_message
    end

    context_section :tasks do
      visible { Conf.available_page_types.include? 'TaskListPage' }
      label  { :tasks.t }
      url    { me_tasks_path }
      active { controller?('me/tasks') }
      icon   :page_tasks
      local_section :pending do
        label  { :pending.t }
        url    { me_tasks_path }
        active { controller?('me/tasks') and params[:view] != 'completed' }
      end
      local_section :completed do
        label  { :completed.t }
        url    { me_tasks_path('view' => 'completed') }
        active { controller?('me/tasks') and params[:view] == 'completed' }
      end
    end

    context_section :settings do
      label  { :settings.t }
      url    { me_settings_path }
      active { controller?('me/settings', 'me/permissions', 'me/profile', 'me/requests', 'me/passwords', 'me/destroys') }
      icon   :control

      local_section :settings do
        label  { :account_settings.t }
        url    { me_settings_path }
        active { controller?('me/settings') }
      end

      local_section :permissions do
        label  { :permissions.t }
        url    { me_permissions_path }
        active { controller?('me/permissions') }
      end

      local_section :profile do
        label  { :profile.t }
        url    { edit_me_profile_path }
        active { controller?('me/profile') }
      end

      local_section :requests do
        label  { :requests.t }
        url    { me_requests_path }
        active { controller?('me/requests') }
      end

      local_section :password do
        label  { :password.t }
        url    { edit_me_password_path }
        active { controller?('me/passwords') }
      end

      local_section :destroy do
        label  { :destroy.t }
        url    { me_destroy_path }
        active { controller?('me/destroys') }
      end
    end
  end

  ##
  ## PEOPLE
  ##

  global_section :people do
    label  { :people.t }
    url    controller: 'person/directory'
    active { controller?('person/directory') || (context?(:user) && visible_context?)}
    html partial: '/layouts/global/nav/people_menu'

    context_section :no_context do
      visible { context?(:none) }
      active  { context?(:none) }

      local_section :contacts do
        visible { logged_in? }
        label { :contacts.t }
        url { people_directory_path(path: ['contacts']) }
        active { params[:path].try(:include?, 'contacts') }
      end

      local_section :peers do
        visible { logged_in? }
        label { :peers.t }
        url { people_directory_path(path: ['peers']) }
        active { params[:path].try(:include?, 'peers') }
      end

      local_section :everybody do
        label { :everybody.t }
        url { people_directory_path(path: ['everybody']) }
        active { params[:path].try(:include?, 'everybody') }
      end
    end

    context_section :profile do
      label  { :profile.t }
      icon   :house
      url    { entity_path(@user) }
      visible { current_user.may?(:view, @user) }
      active { controller?('person/home') }
    end

    context_section :pages do
      label  { :pages.t }
      icon   :page_white_copy
      url    { person_pages_path(@user) }
      visible { current_user.may?(:view, @user) }
      active { page_controller? }
    end
  end

  ##
  ## GROUPS
  ##

  global_section :group do
    label  { :groups.t }
    url    { groups_directory_path }
    active { controller?('group/directory') || ( context?(:group) && visible_context? ) }
    html partial: '/layouts/global/nav/groups_menu'

    context_section :directory do
      visible { context?(:none) }
      active  { context?(:none) }

      local_section :mygroups do
        visible { logged_in? }
        label { :my_groups.t }
        url { groups_directory_path(path: ['my']) }
        active { controller?('group/directory') and params[:path].try(:include?, 'my') }
      end

      local_section :search do
        label { :all_groups.t }
        url { groups_directory_path(path: ['all']) }
        active { controller?('group/directory') and params[:path].try(:include?, 'all') }
      end

      local_section :create do
        label   { :create_thing.t(thing: :group.t) }
        url     { new_group_path }
        active  { controller?('group/groups') }
        icon    :plus
      end
    end

    context_section :home do
      visible { may_show?(@group) }
      label  { :home.t }
      icon   :house
      url    { entity_path(@group) }
      active { controller?('group/home') }
    end

    context_section :pages do
      visible { may_show?(@group) }
      label  { :pages.t }
      icon   :page_white_copy
      url    { group_pages_path(@group) }
      active { page_controller? }
    end

    context_section :members do
      visible { policy(@group).may_list_memberships? }
      label   { :members.t }
      icon    :user
      url     { group_memberships_path(@group) }
      active  { controller?('group/memberships', 'group/invites', 'group/membership_requests') }

      local_section :people do
        visible { policy(@group).may_list_memberships? }
        label   { :people.t }
        url     { group_memberships_path(@group) }
        active  { controller?('group/memberships') and params[:view] != 'groups' }
      end

      local_section :groups do
        visible { policy(@group).may_list_memberships? and @group.network? }
        label   { :groups.t }
        url     { group_memberships_path(@group, view: 'groups') }
        active  { controller?('group/memberships') and params[:view] == 'groups' }
      end

      local_section :invites do
        visible { may_admin?(@group) }
        label   { :send_invites.t }
        url     { new_group_invite_path(@group) }
        active  { controller?('group/invites') }
      end

      local_section :requests do
        visible { may_admin?(@group) }
        label   { :membership_requests.t }
        url     { group_membership_requests_path(@group) }
        active  { controller?('group/membership_requests') }
      end

    end

    context_section :settings do
      visible { may_admin?(@group) }
      label  { :settings.t }
      icon   :control
      url    { group_settings_path(@group) }
      active { controller?('group/settings', 'group/permissions', 'group/profiles', 'group/structures', 'group/archive', 'group/requests', 'group/wikis', 'wiki/versions', 'wiki/diffs') }

      local_section :settings do
        visible { may_admin?(@group) }
        label  { :basic_settings.t }
        url    { group_settings_path(@group) }
        active { controller?('group/settings') }
      end

      local_section :permissions do
        visible { may_admin?(@group) }
        label  { :permissions.t }
        url    { group_permissions_path(@group) }
        active { controller?('group/permissions') }
      end

      local_section :profile do
        visible { may_admin?(@group) }
        label  { :profile.t }
        url    { edit_group_profile_path(@group) }
        active { controller?('group/profiles') }
      end

      local_section :wiki do
        visible { may_admin?(@group) }
        label  { :wiki.t }
        url    { group_wikis_path(@group) }
        active { controller?('group/wikis', 'wiki/versions', 'wiki/diffs') }
      end

      local_section :structure do
        visible { may_admin?(@group) }
        label  { :structure.t }
        url    { group_structure_path(@group) }
        active { controller?('group/structures') }
      end

      local_section :archive do
        visible { may_admin?(@group) }
        label  { :archive.t }
        url    { group_archive_path(@group, action: :index) }
        active { controller?('group/archive') }
      end

      local_section :requests do
        visible { may_admin?(@group) }
        label  { :requests.t }
        url    { group_requests_path(@group) }
        active { controller?('group/requests') }
      end
    end
  end

end
