# A recipe as read from a page's schema.org data. Every field except
# source_url, ingredients, instructions, and nutrition may be nil.
Recipe = Data.define(
  :source_url, :title, :description, :image_url, :servings,
  :prep_time, :cook_time, :total_time,
  :ingredients, :instructions, :nutrition,
  :author, :publisher, :published_on
)

# A run of directions, optionally under a heading such as "For the sauce".
Recipe::Section = Data.define(:name, :steps)
