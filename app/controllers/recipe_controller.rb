class RecipeController < ApplicationController
  require 'hpricot'
  require 'open-uri'

  def index
    recipe_url = params[:recipe_url] || 'http://find.myrecipes.com/recipes/recipefinder.dyn?action=displayRecipe&recipe_id=1891929'
    doc = Hpricot(open(recipe_url.strip))
    @title = doc/"//h1[@id=recipeTitle]"
    @ingredients = doc/"//div[@id=ingredients]/ul/li"
    @preparation = doc/"//div[@id=preparation]/*"

  end
end
