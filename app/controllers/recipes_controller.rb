class RecipesController < ApplicationController
  MAX_LINKS = 10
  RATE_LIMIT = 10
  # Each grab fetches up to MAX_LINKS outside pages, so cap grabs per visitor.
  # A process-local store keeps this working without a shared cache server.
  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new

  rate_limit to: RATE_LIMIT, within: 1.minute, only: :index, store: RATE_LIMIT_STORE,
    with: -> { redirect_to root_path, alert: t("recipes.index.rate_limited") }

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
