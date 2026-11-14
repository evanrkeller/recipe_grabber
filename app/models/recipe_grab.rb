# The outcome of grabbing one recipe link. Links are fetched on their own
# threads so a slow site doesn't hold up the rest.
RecipeGrab = Data.define(:url, :recipe) do
  def self.all(urls)
    threads = urls.map do |url|
      Thread.new { Rails.application.executor.wrap { grab(url) } }
    end
    # Let the worker threads autoload constants while this request thread waits.
    ActiveSupport::Dependencies.interlock.permit_concurrent_loads { threads.map(&:value) }
  end

  def self.grab(url)
    new(url: url, recipe: RecipeParser.new(SafeFetcher.fetch(url), source_url: url).recipe)
  end
end
