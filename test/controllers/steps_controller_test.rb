require "test_helper"

class StepsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get steps_index_url
    assert_response :success
  end

  test "should get update" do
    get steps_update_url
    assert_response :success
  end

  test "should get admin_update" do
    get steps_admin_update_url
    assert_response :success
  end
end
