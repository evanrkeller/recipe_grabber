require "test_helper"

class HomePageTest < ActionDispatch::IntegrationTest
  test "shows the heading and intro" do
    get root_path

    assert_response :success
    assert_select "h1", "Keller Solutions Recipe Grabber"
    assert_select "p", text: /Paste links to recipes from almost any recipe site, one per line/
  end

  test "shows a labeled recipe links text area and a Grab It button that submits by GET" do
    get root_path

    assert_select "form[method=get][action=?]", recipes_path do
      assert_select "label[for=recipe_url]", "Recipe links"
      assert_select "textarea#recipe_url[name=recipe_url]"
      assert_select "button[type=submit]", "Grab It"
    end
  end

  test "is usable on a phone-width screen" do
    get root_path

    assert_select "meta[name=viewport][content*=?]", "width=device-width"
  end

  test "shows the current year in the footer" do
    get root_path

    assert_select "footer", "© #{Date.current.year} Keller Solutions"
  end
end
