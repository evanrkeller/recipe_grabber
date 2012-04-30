class RecipeController < ApplicationController
  require 'hpricot'
  require 'open-uri'

  def index
    recipe_url = params[:recipe_url] || 'http://www.myrecipes.com/recipe/chicken-cashews-10000001891929/'
    doc = Hpricot(open(recipe_url.strip))
    @title = doc/"//h1[@class=x4-headline]"
    @ingredients = doc/"//div[@class=recipeDetails]/ul/li"
    @steps = doc/"//div[@class=recipeDetails]/ol/li"

  end
end
