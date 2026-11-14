class RecipesController < ApplicationController
  def new
  end

  def index
    @results = RecipeGrab.all(recipe_urls)
  end

  private
    def recipe_urls
      params[:recipe_url].to_s.lines.map(&:strip).compact_blank
    end
end
