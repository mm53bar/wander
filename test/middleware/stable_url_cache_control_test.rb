require "test_helper"

class StableUrlCacheControlTest < ActiveSupport::TestCase
  FAR_FUTURE = "public, max-age=31556952".freeze

  def response_for(path)
    app = ->(_env) { [ 200, { "cache-control" => FAR_FUTURE }, [ "" ] ] }
    _status, headers, _body = StableUrlCacheControl.new(app).call("PATH_INFO" => path)
    headers["cache-control"]
  end

  test "the service worker revalidates so a new one can replace it" do
    assert_equal StableUrlCacheControl::REVALIDATE, response_for("/service-worker.js")
  end

  test "the manifest revalidates" do
    assert_equal StableUrlCacheControl::REVALIDATE, response_for("/manifest.webmanifest")
  end

  test "digest-stamped assets keep their far-future expiry" do
    assert_equal FAR_FUTURE, response_for("/assets/application-a1b2c3.css")
  end

  test "pages are left alone" do
    assert_equal FAR_FUTURE, response_for("/trips/1")
  end
end
