# Extracts a Recipe from the schema.org JSON-LD embedded in an HTML page.
# Sites shape this data many ways, so every reader below accepts strings,
# objects, and arrays and quietly drops values it can't make sense of.
class RecipeParser
  JSON_LD_SELECTOR = 'script[type="application/ld+json"]'.freeze

  def initialize(html, source_url:)
    @html = html
    @source_url = source_url
  end

  def recipe
    node = find_recipe_node
    return unless node

    Recipe.new(
      source_url: @source_url,
      title: text(node["name"]),
      description: text(node["description"]),
      image_url: image_url(node["image"]),
      yield: recipe_yield(node["recipeYield"]),
      prep_time: duration(node["prepTime"]),
      cook_time: duration(node["cookTime"]),
      total_time: duration(node["totalTime"]),
      ingredients: list(node["recipeIngredient"]),
      instructions: instructions(node["recipeInstructions"]),
      nutrition: nutrition(node["nutrition"]),
      author: names(node["author"]),
      publisher: names(node["publisher"]),
      published_on: date(node["datePublished"])
    )
  end

  private
    def find_recipe_node
      Nokogiri::HTML(@html).css(JSON_LD_SELECTOR).each do |script|
        node = recipe_in(parse_json(script.text))
        return node if node
      end
      nil
    end

    # Some sites leave raw newlines and tabs inside JSON strings, which strict
    # JSON rejects; outside strings they are plain whitespace, so replacing
    # them with spaces is safe either way.
    def parse_json(source)
      JSON.parse(source.gsub(/[\u0000-\u001f]/, " "))
    rescue JSON::ParserError
      nil
    end

    # Depth-first search, so a Recipe nested under @graph, a top-level array,
    # or a WebPage's mainEntity is found.
    def recipe_in(value)
      case value
      when Array
        value.each do |item|
          found = recipe_in(item)
          return found if found
        end
        nil
      when Hash
        return value if Array(value["@type"]).include?("Recipe")

        recipe_in(value.values)
      end
    end

    def text(value)
      return if value.nil?

      Nokogiri::HTML.fragment(value.to_s).text.squish.presence
    end

    def list(value)
      Array.wrap(value).filter_map { |item| text(item) }
    end

    def image_url(value)
      url = case value
      when Array then return image_url(value.first)
      when Hash then value["url"] || value["contentUrl"]
      else value
      end
      url = url.to_s.strip
      url if url.match?(%r{\Ahttps?://}i)
    end

    # Sites often give both a bare count and a phrase ("6", "6 servings");
    # the phrase reads better.
    def recipe_yield(value)
      values = list(value)
      values.find { |item| item.match?(/[[:alpha:]]/) } || values.first
    end

    def duration(value)
      ActiveSupport::Duration.parse(value.to_s.strip)
    rescue ActiveSupport::Duration::ISO8601Parser::ParsingError
      nil
    end

    def date(value)
      Date.parse(value.to_s)
    rescue Date::Error
      nil
    end

    def names(value)
      list(Array.wrap(value).map { |item| item.is_a?(Hash) ? item["name"] : item }).join(", ").presence
    end

    def nutrition(value)
      return [] unless value.is_a?(Hash)

      value.except("@type", "@context").filter_map do |key, amount|
        amount = text(amount)
        "#{key.delete_suffix("Content").underscore.humanize}: #{amount}" if amount
      end
    end

    def instructions(value)
      value = value.split("\n") if value.is_a?(String)
      items = Array.wrap(value)
      sections, loose = items.partition { |item| item.is_a?(Hash) && item["@type"] == "HowToSection" }

      result = []
      result << Recipe::Section.new(name: nil, steps: steps(loose)) if loose.any?
      sections.each do |section|
        result << Recipe::Section.new(name: text(section["name"]), steps: steps(Array.wrap(section["itemListElement"])))
      end
      result.reject { |section| section.steps.empty? }
    end

    def steps(items)
      items.filter_map { |item| item.is_a?(Hash) ? text(item["text"] || item["name"]) : text(item) }
    end
end
