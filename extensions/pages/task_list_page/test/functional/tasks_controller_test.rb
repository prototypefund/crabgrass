require 'test_helper'

class TasksControllerTest < ActionController::TestCase
  def setup
    @user = users(:blue)
    @page = pages(:tasklist1)
    @page.add(@user, access: :admin)
    @page.save!
    login_as @user
  end

  def test_sort
    assert_equal 1, Task.find(1).position
    assert_equal 2, Task.find(2).position
    assert_equal 3, Task.find(3).position

    post :sort, xhr: true,
      params: { page_id: @page, sort_list_pending: %w[3 2 1] }
    assert_response :success

    assert_equal 3, Task.find(1).position
    assert_equal 2, Task.find(2).position
    assert_equal 1, Task.find(3).position
  end

  def test_create_task
    assert_difference '@page.tasks.count' do
      post :create, xhr: true,
        params: { page_id: @page,
          task: {
            name: 'new task',
            user_ids: [users(:orange).id],
            description: 'new task description'
          }
        }
    end
  end

  def test_update_task
    task = @page.tasks.create name: 'blue... do something!',
                              user_ids: [@user.id]
    assert_difference '@user.tasks.count', -1 do
      put :update, xhr: true,
        params: { page_id: @page, id: task,
          task: { name: 'updated task', description: 'new task description' }
        }
    end
  end
end
