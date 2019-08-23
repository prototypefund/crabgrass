module LoginTestHelper
  def login_as(user)
    user = case user
           when Symbol then users(user)
           when User   then user
           else             nil
    end
    # we set all three by hand because the normal fetching
    # of the user from the session removes mocks and stubs.
    @request.session[:user] = user
    @controller.instance_variable_set :@current_user, user
  end

  # the normal acts_as_authenticated 'login_as' does not work for
  # integration tests
  def login(user)
    post '/account/login', params: { login: user.to_s, password: user.to_s }
  end
end
