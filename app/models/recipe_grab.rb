# The outcome of grabbing one recipe link: a recipe, or the reason there
# isn't one. Links are fetched on their own threads so a slow site doesn't
# hold up the rest. The threads touch no database or request state, and
# Zeitwerk autoloading is thread-safe, so they need no Rails executor.
class RecipeGrab < Data.define(:url, :recipe, :error)
  ERRORS = {
    SafeFetcher::InvalidUrl => :invalid_url,
    SafeFetcher::DisallowedAddress => :disallowed_address,
    SafeFetcher::FetchFailed => :unreachable
  }.freeze

  def self.all(urls)
    urls.map { |url| Thread.new { grab(url) } }.map(&:value)
  end

  def self.grab(url)
    recipe = RecipeParser.new(SafeFetcher.fetch(url), source_url: url).recipe
    return new(url:, recipe:, error: nil) if recipe

    failed(url, :no_recipe, "no schema.org Recipe found")
  rescue SafeFetcher::Error => error
    failed(url, ERRORS.fetch(error.class), error.message)
  rescue StandardError => error
    # One broken site must not take down the other results.
    failed(url, :unreachable, "#{error.class}: #{error.message}")
  end

  # Logs the host, not the full link, which may carry tokens or other personal details.
  def self.failed(url, error, reason)
    Rails.logger.info("[RecipeGrab] #{error} host=#{host_of(url).inspect} reason=#{reason.inspect}")
    new(url:, recipe: nil, error:)
  end

  def self.host_of(url)
    URI.parse(url).host
  rescue URI::Error
    nil
  end
end
