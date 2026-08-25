require "test_helper"

class SafeSendersControllerTest < ActionDispatch::IntegrationTest
  test "settings page lists senders" do
    get settings_path
    assert_response :success
    assert_select "h1", text: /Safe senders/
  end

  test "add a sender" do
    assert_difference -> { SafeSender.count }, 1 do
      post safe_senders_path, params: { safe_sender: { value: "no-reply@newair.example", name: "New Air" } }
    end
    assert_redirected_to safe_senders_path
  end

  test "toggle active" do
    s = safe_senders(:aircanada)
    patch safe_sender_path(s), params: { safe_sender: { active: false } }
    assert_not s.reload.active?
  end

  test "remove a sender" do
    assert_difference -> { SafeSender.count }, -1 do
      delete safe_sender_path(safe_senders(:camis))
    end
  end
end
