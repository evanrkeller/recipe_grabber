require "test_helper"

class SafeFetcherTest < ActiveSupport::TestCase
  PUBLIC_IP = "93.184.216.34".freeze

  setup do
    @original_resolver = SafeFetcher.resolver
    @original_total_timeout = SafeFetcher.total_timeout
    SafeFetcher.resolver = ->(host) { host.end_with?(".internal.test") ? [ "192.168.1.10" ] : [ PUBLIC_IP ] }
  end

  teardown do
    SafeFetcher.resolver = @original_resolver
    SafeFetcher.total_timeout = @original_total_timeout
  end

  test "returns the page body from a public host with a browser-like user agent" do
    stub_request(:get, "https://recipes.example.test/pie").to_return(status: 200, body: "<html>pie</html>")

    assert_equal "<html>pie</html>", SafeFetcher.fetch("  https://recipes.example.test/pie  ")
    assert_requested :get, "https://recipes.example.test/pie", headers: { "User-Agent" => /Mozilla/ }
  end

  test "rejects anything that is not an http or https URL" do
    [ "|ls", "file:///etc/passwd", "ftp://example.test/x", "javascript:alert(1)", "http://", "not a url", "http://exa mple.test", "" ].each do |url|
      assert_raises(SafeFetcher::InvalidUrl, url) { SafeFetcher.fetch(url) }
    end
  end

  test "rejects private, loopback, link-local, and other non-public addresses" do
    %w[
      http://127.0.0.1/ http://localhost.internal.test/ http://10.0.0.5/ http://172.16.3.4/
      http://169.254.169.254/latest/meta-data http://0.0.0.0/ http://100.64.0.1/ http://224.0.0.1/
      http://[::1]/ http://[::ffff:127.0.0.1]/ http://[fe80::1]/ http://[fd00::1]/ http://[::]/
    ].each do |url|
      SafeFetcher.resolver = ->(host) { host.end_with?(".internal.test") ? [ "192.168.1.10" ] : [ host ] }
      assert_raises(SafeFetcher::DisallowedAddress, url) { SafeFetcher.fetch(url) }
    end
  end

  test "rejects a host when any of its addresses is private" do
    SafeFetcher.resolver = ->(_host) { [ PUBLIC_IP, "10.1.2.3" ] }

    assert_raises(SafeFetcher::DisallowedAddress) { SafeFetcher.fetch("http://mixed.example.test/") }
  end

  test "follows a relative redirect to a public page" do
    stub_request(:get, "http://recipes.example.test/old").to_return(status: 301, headers: { "Location" => "/new" })
    stub_request(:get, "http://recipes.example.test/new").to_return(status: 200, body: "moved")

    assert_equal "moved", SafeFetcher.fetch("http://recipes.example.test/old")
  end

  test "rejects a redirect to a private address" do
    stub_request(:get, "http://recipes.example.test/sneaky").to_return(status: 302, headers: { "Location" => "http://admin.internal.test/" })

    assert_raises(SafeFetcher::DisallowedAddress) { SafeFetcher.fetch("http://recipes.example.test/sneaky") }
  end

  test "gives up after three redirects or a redirect without a location" do
    stub_request(:get, %r{http://loop.example.test/\d}).to_return do |request|
      { status: 302, headers: { "Location" => "/#{request.uri.path[1..].to_i + 1}" } }
    end
    stub_request(:get, "http://recipes.example.test/nowhere").to_return(status: 302)

    assert_raises(SafeFetcher::FetchFailed) { SafeFetcher.fetch("http://loop.example.test/1") }
    assert_raises(SafeFetcher::FetchFailed) { SafeFetcher.fetch("http://recipes.example.test/nowhere") }
  end

  test "fails on error responses, timeouts, and connection errors" do
    stub_request(:get, "http://recipes.example.test/missing").to_return(status: 404)
    stub_request(:get, "http://recipes.example.test/forbidden").to_return(status: 403)
    stub_request(:get, "http://recipes.example.test/slow").to_timeout
    stub_request(:get, "http://recipes.example.test/down").to_raise(Errno::ECONNREFUSED)

    %w[missing forbidden slow down].each do |path|
      assert_raises(SafeFetcher::FetchFailed, path) { SafeFetcher.fetch("http://recipes.example.test/#{path}") }
    end
  end

  test "fails on pages over the size limit, whether declared or streamed" do
    stub_request(:get, "http://recipes.example.test/declared")
      .to_return(status: 200, body: "small", headers: { "Content-Length" => (SafeFetcher::MAX_BYTES + 1).to_s })
    stub_request(:get, "http://recipes.example.test/streamed").to_return(status: 200, body: "a" * (SafeFetcher::MAX_BYTES + 1))

    assert_raises(SafeFetcher::FetchFailed) { SafeFetcher.fetch("http://recipes.example.test/declared") }
    assert_raises(SafeFetcher::FetchFailed) { SafeFetcher.fetch("http://recipes.example.test/streamed") }
  end

  test "fails when a download runs past the overall time limit" do
    SafeFetcher.total_timeout = -1
    stub_request(:get, "http://recipes.example.test/drip").to_return(status: 200, body: "slow")

    assert_raises(SafeFetcher::FetchFailed) { SafeFetcher.fetch("http://recipes.example.test/drip") }
  end

  test "fails when the host does not resolve" do
    SafeFetcher.resolver = ->(_host) { raise SocketError, "getaddrinfo: nodename nor servname provided" }
    assert_raises(SafeFetcher::FetchFailed) { SafeFetcher.fetch("http://nope.example.test/") }

    SafeFetcher.resolver = ->(_host) { [] }
    assert_raises(SafeFetcher::FetchFailed) { SafeFetcher.fetch("http://nope.example.test/") }
  end

  test "the default resolver returns the host's IP addresses" do
    assert_includes @original_resolver.call("localhost"), "127.0.0.1"
  end
end
