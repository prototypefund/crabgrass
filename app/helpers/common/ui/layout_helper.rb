module Common::Ui::LayoutHelper
  protected

  ##
  ## TITLE
  ##

  def html_title
    ([@options.try.title] + context_titles + [current_site.title]).compact.join(' - ')
  end

  ##
  ## CLASS
  ##

  def local_class
    if @page
      @page.definition.url
    elsif @group
      @group.type.try.underscore || 'group'
    elsif @user
      @user.class.name.underscore
    end
  end

  ##
  ## STYLESHEET
  ##

  # as needed stylesheets:
  # rather than include every stylesheet in every request, some stylesheets are
  # only included if they are needed. See Application#stylesheet()

  def optional_stylesheets
    stylesheet = controller.class.stylesheets || {}
    [stylesheet[:all], @stylesheet, stylesheet[params[:action].to_sym]].flatten.compact.collect { |i| "as_needed/#{i}" }
  end

  # crabgrass_stylesheets()
  # this is the main helper that is in charge of returning all the needed style
  # elements for HTML>HEAD.

  def crabgrass_stylesheets
    lines = []

    lines << stylesheet_link_tag(current_theme.stylesheet_url('screen'))
    lines << stylesheet_link_tag('icon_png')
    lines << optional_stylesheets.collect do |sheet|
      stylesheet_link_tag(current_theme.stylesheet_url(sheet))
    end
    # we currently do not ship the right to left css
    # if language_direction == "rtl"
    #   lines << stylesheet_link_tag( current_theme.stylesheet_url('rtl') )
    # end
    lines.join("\n").html_safe
  end

  def favicon_link
    if current_theme[:favicon_png] and current_theme[:favicon_ico]
      format('<link rel="shortcut icon" href="%s" type="image/x-icon" /><link rel="icon" href="%s" type="image/x-icon" />', current_theme.url(:favicon_ico), current_theme.url(:favicon_png))
    elsif current_theme[:favicon]
      format('<link rel="icon" href="%s" type="image/x-icon" />', current_theme.url(:favicon))
    end.html_safe
  end

  ##
  ## JAVASCRIPT
  ##

  SPROCKETS_PREFIX = '/static/'.freeze

  #
  # Includes the correct javascript tags for the current request.
  # See ApplicationController#javascript for details.
  #
  def javascript_include_tags
    scripts = controller.class.javascripts || {}
    files = [:application] # asset pipeline js
    files += [scripts[:all], scripts[params[:action].to_sym]].flatten.compact.collect { |i| "as_needed/#{i}" }

    includes = []
    files.each do |file|
      includes << javascript_include_tag(file.to_s)
    end
    includes
  end

  def crabgrass_javascripts
    lines = javascript_include_tags

    # run firebug lite in dev mode for ie
    if Rails.env == 'development'
      lines << '<!--[if IE]>'
      lines << "<script type='text/javascript' src='http://getfirebug.com/firebug-lite-beta.js'></script>"
      lines << '<![endif]-->'
    end

    lines << '<!--[if IE]>'
    lines << javascript_include_tag('shims')
    lines << '<![endif]-->'

    # inline script code
    if content_for?(:script)
      lines << '<script type="text/javascript">'
      lines << content_for(:script)
      lines << '</script>'
    end

    # Autocomplete caches results in sessionStorage. After logging out, the session storage should be cleared.
    unless logged_in?
      lines.push('<script type="text/javascript">if(sessionStorage.length > 0) sessionStorage.clear();</script>')
    end

    lines.join("\n").html_safe
  end

  ##
  ## COLUMN SPANS
  ##

  def center_span_class(column_type)
    side_column_count = current_theme["local_#{column_type}_width"]
    center_column_count = current_theme.grid_column_count - side_column_count
    ["col-xs-12", "col-md-#{center_column_count}"]
  end

  def side_span_class(column_type)
    column_count = current_theme["local_#{column_type}_width"]
    ["col-xs-12", "col-md-#{column_count}"]
  end

  ##
  ## BANNER
  ##

  # banner stuff
  # def banner_style
  #  "background: #{@banner_style.background_color}; color: #{@banner_style.color};" if @banner_style
  # end
  # def banner_background
  #  @banner_style.background_color if @banner_style
  # end
  # def banner_foreground
  #  @banner_style.color if @banner_style
  # end

  ##
  ## CONTEXT STYLES
  ##

  # def background_color
  #  "#ccc"
  # end
  # def background
  #  #'url(/images/test/grey-to-light-grey.jpg) repeat-x;'
  #  'url(/images/background/grey.png) repeat-x;'
  # end

  # return all the custom css which might apply just to this one group
  #  def context_styles
  #    style = []
  #     if @banner
  #       style << '#banner {%s}' % banner_style
  #       style << '#banner a.name_link {color: %s; text-decoration: none;}' %
  #                banner_foreground
  #       style << '#topmenu li.selected span a {background: %s; color: %s}' %
  #                [banner_background, banner_foreground]
  #     end
  #    style.join("\n")
  #  end

  ##
  ## LAYOUT STRUCTURE
  ##

  # builds and populates a table with the specified number of columns
  def column_layout(cols, items, options = {}, &block)
    lines = []
    count = items.size
    rows = (count.to_f / cols).ceil
    width = (100.to_f / cols.to_f).to_i if options[:balanced]
    lines << "<table class='#{options[:class]}' style='#{options[:style]}'>" unless options[:skip_table_tag]
    if options[:header]
      lines << "<tr><th colspan='#{cols}'>#{options[:header]}</th></tr>"
    end
    for r in 1..rows
      lines << ' <tr>'
      for c in 1..cols
        cell = ((r - 1) * cols) + (c - 1)
        next unless items[cell]
        lines << "  <td valign='top' #{"style='width:#{width}%'" if options[:balanced]}>"
        lines << if block
                   yield(items[cell])
                 else
                   format('  %s', items[cell])
                 end
        # lines << "r%s c%s i%s" % [r,c,cell]
        lines << '  </td>'
      end
      lines << ' </tr>'
    end
    lines << '</table>' unless options[:skip_table_tag]
    lines.join("\n").html_safe
  end

  ##
  ## PARTIALS
  ##

  def dialog_page(options = {}, &block)
    block_to_partial('common/dialog_page', options, &block)
  end

  ##
  ## MISC. LAYOUT HELPERS
  ##

  #
  # takes an array of objects and splits it into two even halves. If the count
  # is odd, the first half has one more than the second.
  #
  def even_split(arry)
    cutoff = (arry.count + 1) / 2
    [arry[0..cutoff - 1], arry[cutoff..-1]]
  end

  #
  # acts like haml_tag, capture_haml, or haml_concat, depending on how it is called.
  #
  # two or more args             --> like haml_tag
  # one arg and a block          --> like haml_tag
  # zero args and a block        --> like capture_haml
  # one arg and no block         --> like haml_concat
  #
  # additionally, we allow the use of more than one class.
  #
  # some examples of these usages:
  #
  #   def display_robot(robot)
  #     haml do                                # like capture_haml
  #       haml '.head', robot.head_html        # like haml_tag
  #       haml '.body.metal', robot.body_html  # like haml_tag, but with multiple classes
  #       haml '<a href="/x">link</a>'         # like haml_concat
  #     end
  #   end
  #
  # wrapping the helper in a capture_haml call is very useful, because then
  # the helper can be used wherever a normal helper would be.
  #
  def haml(name = nil, *args, &block)
    if name.present?
      if args.empty? and block.nil?
        haml_concat name
      else
        if name =~ /^(.*?\.[^\.]*)(\..*)$/
          # allow chaining of classes if there are multiple '.' in the first arg
          name = Regexp.last_match(1)
          classes = Regexp.last_match(2).tr('.', ' ')
          hsh = args.detect { |i| i.is_a?(Hash) }
          unless hsh
            hsh = {}
            args << hsh
          end
          hsh[:class] = classes
        end
        haml_tag(name, *args, &block)
      end
    else
      capture_haml(&block)
    end
  end

  #
  # joins an array of elements together using commas.
  #
  def comma_join(*args)
    args.select(&:present?).join(', ')
  end

  #
  # *NEWUI
  #
  # provides a block for main container
  #
  # content_starts_here do
  #   %h1 my page
  #
  # def content_starts_here(&block)
  #  capture_haml do
  #    haml_tag :div, :id =>'main-content' do
  #      haml_concat capture_haml(&block)
  #    end
  #  end
  # end

  ##
  ## declare strings used for logins
  ##
  def login_context
    @login_context ||= {
      strings: {
        login: I18n.t(:login),
        username: I18n.t(:username),
        password: I18n.t(:password),
        forgot_password: I18n.t(:forgot_password_link),
        create_account: I18n.t(:signup_link),
        redirect: params[:redirect] || request.request_uri,
        token: form_authenticity_token
      }
    }
  end
end
