#
# generate links and display of users and groups
#

module Common::Ui::EntityDisplayHelper
  protected

  #
  # linking to users and groups takes a lot of time if we have to fetch the
  # record to get the display name or avatar. if we already have the login or
  # group name, this method is much faster (saves about 150ms per request).
  #
  # think of this as link_to_entity_fast()
  #
  # there are some problems with this code. in particular, it does not handle
  # it very well when the user or group changes their avatar. also, this code
  # duplicates some code in avatar_helper, in the interest of cutting out
  # a lot of logic and method calls.
  #
  # If you do not specify the avatar_id no avatar will be displayed.
  # If you use and avatar id of 0 the fallback avatar will be used instead.
  #
  def link_to_name(name, avatar_id = nil)
    if name
      display_name = name.length > 16 ? force_wrap(name, 16) : name
      if avatar_id.nil?
        format('<a href="/%s" title="%s">%s</a>'.html_safe, name, name, h(display_name))
      else
        # with the id, we can also display the icon
        icon_url = format('/avatars/%s/xsmall.jpg', avatar_id)
        format('<a href="/%s" title="%s" class="icon xsmall single" style="background-image: url(%s)">%s</a>'.html_safe, name, name, icon_url, h(display_name))
      end.html_safe
    else
      :unknown.t
    end
  end

  ##
  ## GROUPS
  ##

  #
  # creates a link to a group. see display_entity for options
  #
  def link_to_group(group, options = nil)
    options = (options || {}).dup
    if group
      unless options[:url] or options[:function]
        options = options.merge url: group_path(group)
      end
    end
    display_entity(group, options)
  end

  ##
  ## USERS
  ##

  #
  # creates a link to a user. see display entity for options
  #
  def link_to_user(user, options = nil)
    options = (options || {}).dup
    if user
      unless options[:url] or options[:function]
        if user.ghost?
          options[:class] = 'ghost'
        else
          options[:url] = user_path(user)
        end
      end
    end
    display_entity(user, options)
  end

  ##
  ## GENERIC PERSON OR GROUP
  ##

  def link_to_entity(entity, options = {})
    return '' unless entity

    if entity.is_a? String
      # this is slow, and should be avoided when displaying lists of entities
      entity = Group.find_by_name(entity) || User.find_by_login(entity)
    end

    if entity.is_a? User
      link_to_user(entity, options)
    elsif entity.is_a? Group
      link_to_group(entity, options)
    else
      display_entity(entity, options)
    end
  end

  #
  # Display a group or user, with or without a link.
  # All such displays should be made by this method.
  #
  # options:
  #
  #   :avatar => nil | :tiny | :xsmall | :small | :medium | :large | :xlarge (default: nil)
  #
  #   :format => :short (entity.name)
  #              :full  (entity.display_name)
  #              :both  (both name and display name)
  #              :two   (both name and display name on two lines)
  #              (default: full)
  #
  #   to create a link, specify one of one of:
  #     (1) :url      => creates a normal link_to
  #     (2) :function => creates a link_to_function
  #
  #   :class => added to the elements's class
  #   :style => added to the element's style
  #
  def display_entity(entity, options = {})
    options ||= {}
    format   = options[:format] || :full
    styles   = [options[:style]]
    classes  = [options[:class], 'entity']

    # avatar

    if options[:avatar]
      classes << options[:avatar]
      classes << 'icon'
      styles  << avatar_style(entity, options[:avatar])
    end

    # label

    display, title = if entity.nil?
                       [:unknown.t, nil]
                     elsif options[:label]
                       [options[:label], nil]
                     elsif format == :short
                       classes << 'single'
                       [entity.name, h(entity.display_name)]
                     elsif format == :full
                       classes << 'single'
                       [h(entity.display_name), entity.name]
                     elsif format == :both
                       classes << 'single'
                       [h(entity.both_names), nil]
                     elsif format == :two
                       if entity.name != entity.display_name
                         ["#{entity.name}<br/>#{h(entity.display_name)}", nil]
                       else
                         classes << 'single'
                         [entity.name, nil]
                       end
    end

    # element

    element_options = { class: classes.join(' '), style: styles.join(';'), title: title }
    if options[:function]
      link_to_function(display, options[:function], element_options)
    elsif options[:url]
      link_to(display, options[:url], element_options)
    else
      content_tag(:div, display, element_options)
    end
  end

  #
  # used when generating json to return for autocomplete popups
  #
  def entity_autocomplete_line(entity)
    format('<em>%s</em>%s', entity.display_name, ('<br/>' + h(entity.name) if entity.display_name != entity.name))
  end

  def entity_list(entities, options = {})
    if entities.any?
      footer_with_more(entities, options)
      entities = entities.limit(options.delete(:limit)) if options[:limit]
      avatar_size = options[:avatar] || current_theme.local_sidecolumn_icon_size
      ul_list_tag(entities, header: options[:header], footer: options[:footer], class: 'entities') do |entity|
        link_to_entity(entity, avatar: avatar_size, class: options[:class])
      end
    end
  end

  def footer_with_more(entities, options)
    return unless options[:limit]
    if options[:more] && entities.count > options[:limit]
      options[:footer] ||= link_to((:see_all_link.t + '&nbsp;&raquo;').html_safe, options[:more])
    end
  end

  #
  # used to convert the text produced by requests into actual links
  #
  def expand_links(text, options = nil)
    if block_given?
      options = text if text.is_a? Hash
      text = yield
    end
    with_html_safety(text) do
      text.to_str.gsub(/<(user|group)>(.*?)<\/(user|group)>/) do |_match|
        if options
          content_tag(:b, link_to_entity(Regexp.last_match(2), options))
        else
          content_tag(:b, link_to_name(Regexp.last_match(2)))
        end
      end
    end
  end

  #
  # converts the link markers in the text of activies and requests in bolded text
  #
  def embold_links(text = nil)
    text = yield if block_given?
    with_html_safety(text) do
      text.to_str.gsub(/<(user|group)>(.*?)<\/(user|group)>/) do |_match|
        content_tag(:b, Regexp.last_match(2))
      end
    end
  end

  def with_html_safety(text)
    text.html_safe? ? yield.html_safe : yield
  end
end
