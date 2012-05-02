class RecipeController < ApplicationController
  require 'nokogiri'
  require 'open-uri'

  def index
    recipe_urls = params[:recipe_url].to_a.map(&:strip)
    @recipes = [].tap do |recipes|
      recipe_urls.each do |recipe_url|
        doc = Nokogiri::HTML(open(recipe_url.strip))
        recipe = {}
        recipe[:title] = doc.search("//meta[@name='recipe_name']/@content").to_s.strip
        recipe[:head_note] = doc.search("//meta[@property='og:description']/@content").to_s.strip
        recipe[:image] = doc.search("//meta[@property='og:image']/@content").to_s.strip
        recipe[:yield] = doc.search("//span[@itemprop='yield']/text()").to_s.strip
        recipe[:prep_time] = doc.search("//time[@itemprop='prepTime']/text()").to_s.strip
        recipe[:cook_time] = doc.search("//time[@itemprop='cookTime']/text()").to_s.strip
        recipe[:total_time] = doc.search("//time[@itemprop='totalTime']/text()").to_s.strip
        recipe[:ingredients] = doc.search("//div[@class='recipeDetails']/ul/li")
        recipe[:steps] = doc.search("//div[@class='recipeDetails']/ol/li")
        recipe[:author] = doc.search("//div[@class='byline']/p[@class='author']/text()")[0].to_s.strip.gsub(/,/, '')
        recipe[:publication] = doc.search("//div[@class='byline']/p[@class='author']/a//text()").to_s.strip
        recipe[:published] = doc.search("//div[@class='byline']/p[@class='author']/span[@itemprop='published']/text()").to_s.strip.capitalize
        recipe[:nutritional_analysis] = doc.search("//ul[@itemprop='nutrition']/li")
        recipes << recipe
      end
    end
  end

end
