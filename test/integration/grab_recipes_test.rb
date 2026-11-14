require "test_helper"

class GrabRecipesTest < ActionDispatch::IntegrationTest
  setup do
    RecipesController::RATE_LIMIT_STORE.clear
    @original_resolver = SafeFetcher.resolver
    SafeFetcher.resolver = ->(_host) { [ "93.184.216.34" ] }
    stub_request(:get, "https://food.example.test/pancakes").to_return(status: 200, body: recipe_fixture("plain_recipe"))
    stub_request(:get, "https://blog.example.test/chili").to_return(status: 200, body: recipe_fixture("graph_recipe"))
    stub_request(:get, "https://media.example.test/banana-bread").to_return(status: 200, body: recipe_fixture("array_recipe"))
  end

  teardown do
    SafeFetcher.resolver = @original_resolver
  end

  test "shows a recipe's title, photo, and description" do
    get recipes_path, params: { recipe_url: "https://food.example.test/pancakes" }

    assert_response :success
    assert_select "article.recipe h2", "Lemon Pancakes"
    assert_select "article.recipe img[src=?][alt=?]", "https://images.example.test/pancakes-440.jpg", "Lemon Pancakes"
    assert_select "article.recipe p", "Thin pancakes with lemon and sugar."
  end

  test "shows yield and times in plain words" do
    get recipes_path, params: { recipe_url: "https://blog.example.test/chili" }

    assert_select "article.recipe" do
      assert_select "dt", "Yield:"
      assert_select "dd", "6 servings"
      assert_select "dd", "15 min"
      assert_select "dd", "1 hr"
      assert_select "dd", "1 hr 15 min"
    end
  end

  test "shows ingredients and numbered directions, grouped into sections" do
    get recipes_path, params: { recipe_url: "https://blog.example.test/chili" }

    assert_select "h3", "Ingredients"
    assert_select "ul.ingredients li", 3
    assert_select "h3", "Directions"
    assert_select "h4", "Chili"
    assert_select "h4", "To serve"
    assert_select "ol.directions", 2
    assert_select "ol.directions li", "Brown the beef with the onion."
  end

  test "shows nutrition, author, publication, and published date" do
    get recipes_path, params: { recipe_url: "https://food.example.test/pancakes" }

    assert_select "h3", "Nutrition"
    assert_select "ul.nutrition li", "Calories: 61 calories"
    assert_select "dd", "Pat Example"
    assert_select "dd", "Example Food"
    assert_select "dd", "March 31, 2025"
  end

  test "shows N/A for details the site does not provide" do
    get recipes_path, params: { recipe_url: "https://media.example.test/banana-bread" }

    assert_select "dt", "Prep Time:"
    assert_select "dd", text: "N/A", minimum: 2
    assert_select "ul.nutrition", count: 0
    assert_select "section.nutrition p", "N/A"
  end

  test "shows every recipe in the order pasted, separated by a divider" do
    get recipes_path, params: { recipe_url: "https://food.example.test/pancakes\r\n\r\nhttps://blog.example.test/chili\nhttps://media.example.test/banana-bread\n" }

    assert_select "article.recipe h2" do |titles|
      assert_equal [ "Lemon Pancakes", "Weeknight Chili & Cornbread", "Banana Bread" ], titles.map(&:text)
    end
    assert_select "hr", 2
  end

  test "keeps pasted links out of the request logs" do
    stub_request(:get, "https://food.example.test/pancakes?token=secret").to_return(status: 200, body: recipe_fixture("plain_recipe"))
    get recipes_path, params: { recipe_url: "https://food.example.test/pancakes?token=secret" }

    assert_includes request.filtered_path, "recipe_url=[FILTERED]"
    assert_not_includes request.filtered_path, "secret"
  end

  test "links each recipe back to its original page and keeps results out of search engines" do
    get recipes_path, params: { recipe_url: "https://food.example.test/pancakes" }

    assert_select "a[href=?]", "https://food.example.test/pancakes", "View original recipe"
    assert_select "meta[name=robots][content=noindex]"
  end
end
