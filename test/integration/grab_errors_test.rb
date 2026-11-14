require "test_helper"

class GrabErrorsTest < ActionDispatch::IntegrationTest
  setup do
    @original_resolver = SafeFetcher.resolver
    SafeFetcher.resolver = ->(host) { host == "router.internal.test" ? [ "192.168.0.1" ] : [ "93.184.216.34" ] }
    stub_request(:get, "https://food.example.test/pancakes").to_return(status: 200, body: recipe_fixture("plain_recipe"))
    stub_request(:get, "https://food.example.test/about").to_return(status: 200, body: recipe_fixture("no_recipe"))
    stub_request(:get, "https://blocked.example.test/pie").to_return(status: 403)
    stub_request(:get, "https://slow.example.test/pie").to_timeout
  end

  teardown do
    SafeFetcher.resolver = @original_resolver
  end

  test "an empty submission returns to the form with a message" do
    get recipes_path, params: { recipe_url: " \n \n" }

    assert_redirected_to root_path
    follow_redirect!
    assert_select ".flash-alert", "Paste at least one recipe link."
    assert_select "textarea#recipe_url"
  end

  test "more than 10 links returns to the form with a message and keeps what was pasted" do
    pasted = (1..11).map { |n| "https://food.example.test/#{n}" }.join("\n")

    get recipes_path, params: { recipe_url: pasted }

    assert_redirected_to root_path(recipe_url: pasted)
    follow_redirect!
    assert_select ".flash-alert", "You can grab up to 10 recipes at a time."
    assert_select "textarea#recipe_url", text: /food.example.test\/11/
    assert_not_requested :get, %r{food.example.test/\d+}
  end

  test "explains each link that could not be grabbed, names it, and still shows the rest" do
    pasted = [
      "|ls -la",
      "http://router.internal.test/admin",
      "https://blocked.example.test/pie",
      "https://slow.example.test/pie",
      "https://food.example.test/about",
      "https://food.example.test/pancakes"
    ].join("\n")

    get recipes_path, params: { recipe_url: pasted }

    assert_response :success
    assert_grab_error 0, "That doesn't look like a web address.", "|ls -la"
    assert_grab_error 1, "That address isn't allowed.", "http://router.internal.test/admin"
    assert_grab_error 2, "We couldn't reach that page.", "https://blocked.example.test/pie"
    assert_grab_error 3, "We couldn't reach that page.", "https://slow.example.test/pie"
    assert_grab_error 4, "We couldn't find a recipe on that page.", "https://food.example.test/about"
    assert_select "article.recipe h2", "Lemon Pancakes"
    assert_select "hr", 5
  end

  test "a recipe without a name still gets a heading" do
    stub_request(:get, "https://food.example.test/nameless")
      .to_return(status: 200, body: %(<script type="application/ld+json">{"@type":"Recipe"}</script>))

    get recipes_path, params: { recipe_url: "https://food.example.test/nameless" }

    assert_select "article.recipe h2", "Untitled recipe"
  end

  private
    def assert_grab_error(index, message, url)
      error = css_select("article.grab-error")[index]
      assert error, "expected a grab error at position #{index}"
      assert_equal message, error.at_css(".grab-error-message").text
      assert_equal url, error.at_css(".grab-error-link").text
    end
end
