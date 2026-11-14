class RecipesController < ApplicationController
  MAX_LINKS = 10

  def new
    @recipe_url = params[:recipe_url]
  end

  def index
    urls = recipe_urls

    if urls.empty?
      redirect_to root_path, alert: t(".empty")
    elsif urls.size > MAX_LINKS
      redirect_to root_path(recipe_url: params[:recipe_url]), alert: t(".too_many", count: MAX_LINKS)
    else
      @grabs = RecipeGrab.all(urls)
    end
  end

  private
    def recipe_urls
      params[:recipe_url].to_s.lines.map(&:strip).compact_blank
    end
end
