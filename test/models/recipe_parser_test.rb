require "test_helper"

class RecipeParserTest < ActiveSupport::TestCase
  def parse(name, source_url: "https://example.test/recipe")
    RecipeParser.new(recipe_fixture(name), source_url: source_url).recipe
  end

  test "reads a plain Recipe node" do
    recipe = parse("plain_recipe")

    assert_equal "https://example.test/recipe", recipe.source_url
    assert_equal "Lemon Pancakes", recipe.title
    assert_equal "Thin pancakes with lemon and sugar.", recipe.description
    assert_equal "https://images.example.test/pancakes-440.jpg", recipe.image_url
    assert_equal "Makes 12", recipe.servings
    assert_equal 10.minutes, recipe.prep_time
    assert_equal 20.minutes, recipe.cook_time
    assert_equal 30.minutes, recipe.total_time
    assert_equal [ "100g plain flour", "2 large eggs", "300ml milk" ], recipe.ingredients
    assert_equal [ nil ], recipe.instructions.map(&:name)
    assert_equal [ "Whisk the flour, eggs and milk into a smooth batter.", "Cook ladlefuls in a hot pan for 1 minute each side." ],
      recipe.instructions.first.steps
    assert_equal [ "Calories: 61 calories", "Fat: 2 grams fat", "Protein: 2 grams protein" ], recipe.nutrition
    assert_equal "Pat Example", recipe.author
    assert_equal "Example Food", recipe.publisher
    assert_equal Date.new(2025, 3, 31), recipe.published_on
  end

  test "finds the Recipe inside an @graph and keeps instruction sections" do
    recipe = parse("graph_recipe")

    assert_equal "Weeknight Chili & Cornbread", recipe.title
    assert_equal "https://blog.example.test/chili-1x1.jpg", recipe.image_url
    assert_equal "6 servings", recipe.servings
    assert_equal 75.minutes, recipe.total_time
    assert_equal [ "Chili", "To serve" ], recipe.instructions.map(&:name)
    assert_equal [ "Brown the beef with the onion.", "Add the beans and simmer for 45 minutes." ], recipe.instructions.first.steps
    assert_equal [ "Ladle into bowls." ], recipe.instructions.last.steps
    assert_empty recipe.nutrition
    assert_equal "Sam Example", recipe.author
    assert_nil recipe.publisher
    assert_equal 15.minutes, recipe.prep_time
  end

  test "reads a top-level array with a multi-type node and skips invalid JSON-LD blocks" do
    recipe = parse("array_recipe")

    assert_equal "Banana Bread", recipe.title
    assert_equal "https://media.example.test/banana-bread.jpg", recipe.image_url
    assert_equal "1 loaf", recipe.servings
    assert_nil recipe.prep_time
    assert_nil recipe.cook_time
    assert_equal 65.minutes, recipe.total_time
    assert_nil recipe.description
    assert_equal [ "Mash the bananas with the butter.", "Bake at 350°F for 1 hour." ], recipe.instructions.first.steps
    assert_equal "Alex Example, Jo Example", recipe.author
    assert_equal "Example Recipes", recipe.publisher
    assert_equal Date.new(2023, 5, 1), recipe.published_on
  end

  test "returns nil when the page has no Recipe data" do
    assert_nil parse("no_recipe")
    assert_nil RecipeParser.new("<html><body>Nothing here</body></html>", source_url: "https://example.test").recipe
  end

  test "tolerates loosely shaped values" do
    html = <<~HTML
      <script type="application/ld+json">
      {"@type":"WebPage","mainEntity":{"@type":"Recipe","name":"  Toast <b>with</b>\n butter ",
       "image":"javascript:alert(1)","recipeYield":4,"prepTime":"not a duration","datePublished":"someday",
       "recipeIngredient":"1 slice bread","recipeInstructions":"Toast the bread.\\nButter it.",
       "author":"Chris Example","publisher":"Toast Weekly",
       "nutrition":{"@type":"NutritionInformation","servingSize":"1 slice","calories":""}}}
      </script>
    HTML

    recipe = RecipeParser.new(html, source_url: "https://example.test").recipe

    assert_equal "Toast with butter", recipe.title
    assert_nil recipe.image_url
    assert_equal "4", recipe.servings
    assert_nil recipe.prep_time
    assert_nil recipe.published_on
    assert_equal [ "1 slice bread" ], recipe.ingredients
    assert_equal [ "Toast the bread.", "Butter it." ], recipe.instructions.first.steps
    assert_equal "Chris Example", recipe.author
    assert_equal "Toast Weekly", recipe.publisher
    assert_equal [ "Serving size: 1 slice" ], recipe.nutrition
  end

  test "uses a step's name when it has no text, and an image's contentUrl" do
    html = <<~HTML
      <script type="application/ld+json">
      {"@type":"Recipe","name":"Tea","image":[{"@type":"ImageObject","contentUrl":"https://example.test/tea.jpg"}],
       "recipeInstructions":[{"@type":"HowToStep","name":"Steep for 3 minutes."},{"@type":"HowToStep"}]}
      </script>
    HTML

    recipe = RecipeParser.new(html, source_url: "https://example.test").recipe

    assert_equal "https://example.test/tea.jpg", recipe.image_url
    assert_equal [ "Steep for 3 minutes." ], recipe.instructions.first.steps
    assert_empty recipe.ingredients
    assert_nil recipe.servings
  end

  test "accepts prefixed types, JSON-LD value objects, and ignores linked-data keys" do
    html = <<~HTML
      <script type="application/ld+json">
      {"@type":"schema:Recipe","name":{"@value":"Porridge"},"description":{"@id":"#desc"},
       "datePublished":"#{"2024" * 40}",
       "recipeInstructions":[{"@type":["HowToSection"],"name":"Cook","itemListElement":["Simmer the oats."]}],
       "nutrition":{"@type":"NutritionInformation","@id":"#nutrition","calories":"150 calories"}}
      </script>
    HTML

    recipe = RecipeParser.new(html, source_url: "https://example.test").recipe

    assert_equal "Porridge", recipe.title
    assert_nil recipe.description
    assert_nil recipe.published_on
    assert_equal [ "Cook" ], recipe.instructions.map(&:name)
    assert_equal [ "Calories: 150 calories" ], recipe.nutrition
    full_url_type = %(<script type="application/ld+json">{"@type":"http://schema.org/Recipe","name":"Gruel"}</script>)
    assert_equal "Gruel", RecipeParser.new(full_url_type, source_url: "https://example.test").recipe.title
  end

  test "keeps loose steps and sections in their original order and drops empty sections" do
    html = <<~HTML
      <script type="application/ld+json">
      {"@type":"Recipe","name":"Soup","recipeInstructions":[
        {"@type":"HowToStep","text":"Preheat the pot."},
        {"@type":"HowToSection","name":"Cook","itemListElement":[{"@type":"HowToStep","text":"Simmer."}]},
        {"@type":"HowToStep","text":"Serve."},
        {"@type":"HowToStep","text":"Garnish."},
        {"@type":"HowToSection","name":"Notes","itemListElement":[]}]}
      </script>
    HTML

    sections = RecipeParser.new(html, source_url: "https://example.test").recipe.instructions

    assert_equal [ nil, "Cook", nil ], sections.map(&:name)
    assert_equal [ [ "Preheat the pot." ], [ "Simmer." ], [ "Serve.", "Garnish." ] ], sections.map(&:steps)
  end

  test "has no instructions when the recipe provides none" do
    html = %(<script type="application/ld+json">{"@type":"Recipe","name":"Mystery"}</script>)

    assert_empty RecipeParser.new(html, source_url: "https://example.test").recipe.instructions
  end
end
