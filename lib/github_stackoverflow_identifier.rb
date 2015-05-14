require './lib/object_identifier'
require 'neo4j'

class ObjectIdentifier
  module Matchers
    def self.image_similarity_matcher(neo_id1, neo_id2, options = {})
      score = image_similarities[[neo_id1, neo_id2]] || 0.0

      score > options[:threshold] ? score : 0
    end

    private

    def self.image_similarities
      return @image_similarities if @image_similarities

      @image_similarities = {}

      query = Neo4j::Session.current.query

      query.match(u1: :User, u2: :User).match('u1-[rel:COMPUTER_IDENTIFIED]-u2').delete(:rel).exec
      query.match(u1: :User, u2: :User).match('u1-[rel:COMPUTER_IDENTIFIED_PROPERTY]-u2').delete(:rel).exec

      query.match('(sou:StackOverflow:User)-[r:SIMILAR_IMAGE_TO]->(ghu:GitHub:User)').pluck('ID(sou), r.distance, ID(ghu)').each do |sou_id, distance, ghu_id|
        score = (15.0 - distance) / 15.0

        @image_similarities[[sou_id, ghu_id]] = score
        @image_similarities[[ghu_id, sou_id]] = score
      end

      @image_similarities
    end
  end
end

class GithubStackoverflowIdentifier < ObjectIdentifier
  def initialize(weights = {})
    super() do |config|
      config.default_threshold = 0.7
      config.default_weight = 1.0

      matchers = {
        [:name, :display_name] => :fuzzy_string,
        [:login, :display_name] => :fuzzy_string,
        [:blog, :website_url] => :fuzzy_string,
        [:location, :location] => :fuzzy_string,

        [:login, :github_username] => :exact_string,
        [:twitter_username, :twitter_username] => :exact_string,

        [:uncommon_domains, :uncommon_domains] => :array_fuzzy_string,
        [:usernames, :usernames] => :array_exact_string,

        [:neo_id, :neo_id] => :image_similarity
      }

      thresholds = {
        [:uncommon_domains, :uncommon_domains] => 0.97,
        [:usernames, :usernames] => 0.97
      }

      matchers.each do |key, matcher|
        config.add_matcher key[0], key[1], matcher, threshold: thresholds[key], weight: weights[key]
      end

      yield config if block_given?
    end
  end

end


