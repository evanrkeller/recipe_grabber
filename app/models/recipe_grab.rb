# The outcome of grabbing one recipe link: a recipe, or the reason there
# isn't one. Links are fetched on their own threads so a slow site doesn't
# hold up the rest.
RecipeGrab = Data.define(:url, :recipe, :error) do
  ERRORS = {
    SafeFetcher::InvalidUrl => :invalid_url,
    SafeFetcher::DisallowedAddress => :disallowed_address,
    SafeFetcher::FetchFailed => :unreachable
  }.freeze

  def self.all(urls)
    threads = urls.map do |url|
      Thread.new { Rails.application.executor.wrap { grab(url) } }
    end
    # Let the worker threads autoload constants while this request thread waits.
    ActiveSupport::Dependencies.interlock.permit_concurrent_loads { threads.map(&:value) }
  end

  def self.grab(url)
    recipe = RecipeParser.new(SafeFetcher.fetch(url), source_url: url).recipe
    return new(url:, recipe:, error: nil) if recipe

    failed(url, :no_recipe, "no schema.org Recipe found")
  rescue SafeFetcher::Error => error
    failed(url, ERRORS.fetch(error.class), error.message)
  end

  # Logs the host, not the full link, which may carry tokens or other personal details.
  def self.failed(url, error, reason)
    host = URI.parse(url).host rescue nil
    Rails.logger.info("[RecipeGrab] #{error} host=#{host.inspect} reason=#{reason.inspect}")
    new(url:, recipe: nil, error:)
  end
end
