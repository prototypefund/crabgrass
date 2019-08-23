#
# Basic account management, for unauthenticated users.
#
# Authenticated user stuff is in Me::SettingsController.
#
# Login and logout are in SessionController.
#

class AccountsController < ApplicationController
  layout 'notice'

  ##
  ## SIGNUP
  ##

  #
  # allow the user to request a new user account.
  #
  def new
    @user = User.new(user_params)
  end

  #
  # actually create the new user account
  #
  def create
    @user = User.new(user_params)

    @user.language   = session[:language_code].to_s
    @user.avatar     = Avatar.new
    @user.save!
    session[:signup_email_address] = nil
    self.current_user = @user

    redirect_to(params[:redirect] || current_site.login_redirect_url)
    success :signup_success.t, :signup_success_message.t
  end

  ##
  ## VERIFICATION
  ##

  # removed

  ##
  ## PASSWORD RESET
  ##

  public

  def reset_password
    if params[:token].nil?
      if request.get?
        reset_password_form           # step 1
      elsif request.post?
        send_reset_token              # step 2
      end
    else
      if request.get?
        reset_password_confirmation   # step 3
      elsif request.post?
        set_new_password              # step 4
      end
    end
  end

  protected

  # session[:signup_email_address] is used when accepting an invite to join
  # a group, but you don't have an account yet.
  # First, you accept the invite, then you get the option to sign up.
  # In this case, we already know the email, and we don't want the user to
  # be able to change it.
  def user_params
    user_params = params.fetch(:user, {})
    if session[:signup_email_address].present?
      user_params[:email] = session[:signup_email_address]
    end
    user_params.permit :login, :email, :password, :password_confirmation,
                       :language, :display_name
  end

  def reset_password_form
    render template: 'accounts/reset_password'
  end

  #
  # send the reset password token via email to the user.
  # it's an information leak to tell the user that the email address couldn't be
  # found, so we always report success. this is a problem, but there is no good
  # solution.
  #
  def send_reset_token
    if ValidatesEmailFormatOf.validate_email_format(params[:email])
      error :invalid_email_text.t
      return
    end

    sleep(rand * 3) # an attempt to make timing attacks harder

    user = User.find_by_email params[:email]
    if user
      token = User::Token.to_recover.create(user: user)
      Mailer.forgot_password(token, mailer_options).deliver_now
    end

    # this gives success even if there is no user, to not confirm that an email is in db
    success :reset_password.t, :reset_password_email_sent.t
    render_alert
  end

  def reset_password_confirmation
    confirm_token or return
    render template: 'accounts/reset_password_confirmation'
  end

  def set_new_password
    confirm_token or return

    @user.password              = params[:new_password]
    @user.password_confirmation = params[:password_confirmation]
    if @user.save
      Mailer.reset_password(@user, mailer_options).deliver_now
      @token.destroy
      success :password_reset.t, :password_reset_ok_text.t, :nofade
      redirect_to root_path
    else
      error @user
      render_alert
    end
  end

  #
  # confirms that the token is valid, returns false otherwise.
  #
  def confirm_token
    # FIXME: rather permit less
    params.permit!.to_h if params
    @token = User::Token.to_recover.active.find_by_param(params[:token])
    if @token.present?
      @user = @token.user
    else
      error :invalid_token.t, :invalid_token_text.t
      render_alert
      return false
    end
  end
end
