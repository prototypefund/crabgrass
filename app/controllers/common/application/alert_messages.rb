# -*- coding: utf-8 -*-
#
# Four different alert methods:
#
#  error()   -- when something has gone horribly wrong. RED
#  warning() -- bad input or permissioned denied. YELLOW
#  notice()  -- information, but not necessarily bad or good. BLUE.
#  success() -- yeah, confirmation that something went right. GREEN.
#
# If message is empty, these standard messages are shown:
#
#  error: "Changes could not be saved"
#  warning: "Changes could not be saved"
#  notice: no default
#  success: "Changes saved"
#
# The alert methods accept arguments, in any order, that are Strings, Exceptions,
# Arrays or Symbols.
#
# Exception    -- display an alert appropriate to the exception.
# String       -- displays the content of the string.
# Array        -- displays each of the strings in the array, each on their own line.
# ActiveRecord -- displays the validation errors for the object.
# Symbol       -- set options with the alert message:
#
#    Available options:
#      :now    -- flash now
#      :later  -- flash later
#      :fade   -- hide message after 5 seconds
#                 (by default, success and notice messages fade.)
#      :quick  -- fade, but start immediately.
#      :nofade -- prevent fade
#
# Flash now or flash later? The code tries to pick an intelligent default:
#
# Flash now:
#  - ajax requests
#  - post/put with error
#
# Flash later
#  - @preformed_redirect is true
#  - get requests
#  - post/put with success
#
# NOTE: i think @preformed_redirect is undocumented and might change in the future.
#

require 'active_support/multibyte/chars'

module Common::Application::AlertMessages
  def self.included(base)
    base.class_eval do
      helper_method :translate_exception
    end
  end

  protected

  ##
  ## GENERATING ALERTS
  ##

  def error(*args)
    alert_message(:error, *args)
  end

  def warning(*args)
    alert_message(:warning, *args)
  end

  def notice(*args)
    alert_message(:notice, *args)
  end

  def success(*args)
    alert_message(:success, *args)
  end

  def alert_message(*args)
    options = Hash[args.collect { |i| [i, true] if i.is_a?(Symbol) }.compact]
    type = determine_type(options)
    flsh = determine_flash(type, options)
    flsh[:messages] ||= []
    add_flash(type, *args).each do |msg|
      # allow options to override the defaults
      flsh[:messages] << msg.merge(options)
    end
  end

  #
  # forces the alert messages to come later, even if we previously said :now.
  # this is used in case we did :now but then redirected later.
  #
  def force_later_alert
    flash[:messages] = flash.now[:messages]
  end

  #
  # We use the default rails error to trigger the ErrorApp middleware.
  # This will then in turn call ExceptionsController#show as defined in
  # config.exceptions_app
  #
  # Why?
  # Because we need to get rid of all Controller state.
  #  * Instance variables may leak information.
  #  * Controller functions like setup_navigation may crash.
  #
  # At the same time redirect would alter the url in the users browser.
  # Maybe they just typed it wrong. So we better leave it there.
  #
  def raise_not_found(thing = nil)
    raise ErrorNotFound.new(thing)
  end

  private

  ##
  ## BUILDING THE MESSAGE
  ##

  def add_flash(type, *args)
    if exception = args.detect { |a| a.is_a? Exception }
      add_flash_exception(exception)
    elsif record = args.detect { |a| a.is_a? ActiveRecord::Base }
      add_flash_record(record, args.extract_options!)
    elsif (messages = args.select { |a| a.is_a?(String) or a.is_a?(ActiveSupport::Multibyte::Chars) }).any?
      add_flash_message(type, messages)
    elsif message_array = args.detect { |a| a.is_a?(Array) }
      add_flash_message(type, message_array)
    else
      add_flash_default(type)
    end
  end

  def add_flash_message(type, message)
    [{ type: type, text: message }]
  end

  def add_flash_default(type)
    msg = if type == :error or type == :warning
            :alert_not_saved.t
          else
            :alert_saved.t
    end
    add_flash_message(type, msg)
  end

  def add_flash_exception(exception)
    if exception.is_a? PermissionDenied
      [{ type: :warning, text: [:permission_denied.t, :permission_denied_description.t] }]
    elsif exception.is_a? AuthenticationRequired
      [{ type: :notice, text: [:login_required.t, :login_required_description.t] }]
    elsif exception.is_a? ErrorMessages
      exception.errors.collect do |msg|
        { type: :error, text: msg }
      end
    elsif exception.is_a? ActiveRecord::RecordInvalid
      add_flash_record(exception.record)
    elsif exception.is_a? CrabgrassException
      [{ type: exception.options[:type] || :error, text: exception.message }]
    else
      text = exception.respond_to?(:message) ? exception.message : exception
      [{ type: :error, text: text.to_s }]
    end
  end

  def add_flash_record(record, options = {})
    if record.respond_to?(:flash_message) && record.flash_message
      options[:count] ||= 1
      [record.flash_message(options)]
    elsif record.errors.any?
      [{ type: :error,
         text: [:alert_not_saved.t, :alert_field_errors.t],
         list: record.errors.full_messages }]
    else
      [{ type: :success,
         text: :alert_saved.t }]
    end
  end

  #
  # make a good guess as to what kind of flash we want, and allow an overide
  #
  def determine_flash(type, options)
    if options[:now]
      flash.now
    elsif options[:later]
      flash
    elsif @performed_redirect
      flash
    elsif (request.post? or request.put?) and (type == :error or type == :warning)
      flash.now
    elsif request.xhr?
      flash.now
    else
      flash
    end
  end

  def determine_type(options)
    if options[:error];      :error
    elsif options[:warning]; :warning
    elsif options[:notice];  :notice
    elsif options[:success]; :success
    end
  end

  # assumes @exception to be set to the exception to translate
  def translate_exception(scope)
    keys = ActionDispatch::ExceptionWrapper.rescue_responses
    key = keys[@exception.class.name]
    options = @exception.respond_to?(:options) ? @exception.options : {}
    scope = [:exception, scope, options[:thing]].compact
    thing = I18n.t(options[:thing], default: '')
    I18n.t key, scope: scope, thing: thing, cascade: true
  end

end
