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
      servings: servings(node["recipeYield"]),
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
      documents = Nokogiri::HTML(@html).css(JSON_LD_SELECTOR).map { |script| parse_json(script.text) }
      @nodes_by_id = index_by_id(documents)
      documents.each do |document|
        node = recipe_in(document)
        return node if node
      end
      nil
    end

    # Every object on the page with an @id, so references like
    # {"@id": "#author"} can be followed without fetching anything.
    def index_by_id(value, index = {})
      case value
      when Array then value.each { |item| index_by_id(item, index) }
      when Hash
        index[value["@id"]] ||= value if value["@id"].is_a?(String) && value.keys.size > 1
        value.each_value { |item| index_by_id(item, index) }
      end
      index
    end

    def dereference(value)
      return value unless value.is_a?(Hash) && value["@id"] && (value.keys - %w[@id @type]).empty?

      @nodes_by_id.fetch(value["@id"], value)
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
        return value if type?(value, "Recipe")

        recipe_in(value.values)
      end
    end

    # Matches "Recipe", "schema:Recipe", and "http://schema.org/Recipe".
    def type?(node, name)
      Array(node["@type"]).any? { |type| type.to_s.split(%r{[/:]}).last == name }
    end

    # JSON-LD may wrap a string as {"@value": "..."}; other objects aren't text.
    def text(value)
      value = value["@value"] if value.is_a?(Hash)
      return if value.nil? || value.is_a?(Hash) || value.is_a?(Array)

      Nokogiri::HTML.fragment(value.to_s).text.squish.presence
    end

    def list(value)
      Array.wrap(value).filter_map { |item| text(item) }
    end

    def image_url(value)
      value = dereference(value)
      url = case value
      when Array then return image_url(value.first)
      when Hash then value["url"] || value["contentUrl"]
      else value
      end
      absolute_http_url(url.to_s.strip)
    end

    # Resolves "/images/pie.jpg" and "//cdn.example/pie.jpg" against the
    # recipe page, then allows only http(s) results.
    def absolute_http_url(url)
      return if url.empty?

      resolved = URI.join(@source_url, url)
      resolved.to_s if resolved.is_a?(URI::HTTP) && resolved.host.present?
    rescue URI::Error
      nil
    end

    # Sites often give both a bare count and a phrase ("6", "6 servings");
    # the phrase reads better.
    def servings(value)
      values = list(value)
      values.find { |item| item.match?(/[[:alpha:]]/) } || values.first
    end

    # An absurd value like "PT999...9.0H" parses to infinity, which can't be displayed.
    def duration(value)
      parsed = ActiveSupport::Duration.parse(value.to_s.strip)
      parsed if parsed.value.finite?
    rescue ActiveSupport::Duration::ISO8601Parser::ParsingError
      nil
    end

    def date(value)
      Date.parse(value.to_s)
    rescue Date::Error, ArgumentError # Date.parse raises ArgumentError for strings over 128 characters
      nil
    end

    def names(value)
      list(Array.wrap(value).map { |item| (item = dereference(item)).is_a?(Hash) ? item["name"] : item }).join(", ").presence
    end

    def nutrition(value)
      return [] unless value.is_a?(Hash)

      value.reject { |key, _| key.start_with?("@") }.filter_map do |key, amount|
        amount = text(amount)
        "#{key.delete_suffix("Content").underscore.humanize}: #{amount}" if amount
      end
    end

    # Keeps the source order: each HowToSection becomes its own section, and
    # each run of loose steps between sections becomes an unnamed one.
    def instructions(value)
      value = value.split("\n") if value.is_a?(String)
      groups = Array.wrap(value).chunk_while { |a, b| !section?(a) && !section?(b) }

      groups.filter_map do |group|
        section = if section?(group.first)
          Recipe::Section.new(name: text(group.first["name"]), steps: steps(Array.wrap(group.first["itemListElement"])))
        else
          Recipe::Section.new(name: nil, steps: steps(group))
        end
        section if section.steps.any?
      end
    end

    def section?(item)
      item.is_a?(Hash) && type?(item, "HowToSection")
    end

    def steps(items)
      items.filter_map { |item| item.is_a?(Hash) ? text(item["text"] || item["name"]) : text(item) }
    end
end
