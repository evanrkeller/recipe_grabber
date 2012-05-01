class RecipeController < ApplicationController
  require 'nokogiri'
  require 'open-uri'

  def index
    recipe_url = params[:recipe_url] || 'http://www.myrecipes.com/recipe/chicken-cashews-10000001891929/'
    doc = Nokogiri::HTML(open(recipe_url.strip))
    @title = doc.search("//meta[@name='recipe_name']/@content").to_s.strip
    @head_note = doc.search("//meta[@property='og:description']/@content").to_s.strip
    @image = doc.search("//meta[@property='og:image']/@content").to_s.strip
    @yield = doc.search("//span[@itemprop='yield']/text()").to_s.strip
    @prep_time = doc.search("//time[@itemprop='prepTime']/text()").to_s.strip
    @cook_time = doc.search("//time[@itemprop='cookTime']/text()").to_s.strip
    @total_time = doc.search("//time[@itemprop='totalTime']/text()").to_s.strip
    @ingredients = doc.search("//div[@class='recipeDetails']/ul/li")
    @steps = doc.search("//div[@class='recipeDetails']/ol/li")
    @author = doc.search("/div[@class='byline']/p[@class='author']/text()[1]")
    @publication = doc.search("//div[@class='byline']/p[@class='author']/a//text()").to_s.strip
    @published = doc.search("//div[@class='byline']/p[@class='author']/span[@itemprop='published']/text()").to_s.strip.capitalize
    @nutritional_analysis = doc.search("//ul[@itemprop='nutrition']/li")

  end
end
