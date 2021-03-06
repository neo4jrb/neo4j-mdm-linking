require 'fuzzystringmatch'
require 'ostruct'

class ObjectIdentifier
  module Matchers
    JAROW = FuzzyStringMatch::JaroWinkler.create( :native )

    def self.fuzzy_string_matcher(value1, value2, options = {})
      stripped1 = value1.to_s.strip
      stripped2 = value2.to_s.strip
      if stripped1.empty? || stripped2.empty? || stripped1.size < 3 || stripped2.size < 3
        0.0
      else
        score = JAROW.getDistance(value1.downcase, value2.downcase)
        score > options[:threshold] ? score : 0
      end
    end

    def self.exact_string_matcher(value1, value2, options = {})
      value1 = value1.to_s.strip.downcase
      value2 = value2.to_s.strip.downcase
      (value1.size >= 1 && value1 == value2) ? 1.0 : 0.0
    end

    def self.array_fuzzy_string_matcher(array1, array2, options = {})
      array_matcher(:fuzzy_string_matcher, array1, array2, options)
    end

    def self.array_exact_string_matcher(array1, array2, options = {})
      array_matcher(:exact_string_matcher, array1, array2, options)
    end

    def self.array_matcher(single_matcher, array1, array2, options = {})
      array1.map do |value1|
        array2.map do |value2|
          send(single_matcher, value1, value2, options)
        end
      end.flatten.sum
    end
  end

  class Config
    attr_accessor :classifier, :default_threshold, :default_weight

    def add_matcher(property1, property2, matcher, options = {})
      if matcher.is_a?(Symbol) || matcher.is_a?(String)
        matcher = Matchers.method("#{matcher}_matcher")
      end

      matchers << OpenStruct.new(property1: property1,
                                 property2: property2,
                                 options: options,
                                 block: matcher)
    end

    def matchers
      @matchers ||= []
    end
  end

  def initialize
    yield config
  end

  def config
    @config ||= Config.new
  end

  DEFAULT_MATCHER = proc do |value1, value2, options = {}|
    stripped1 = value1.to_s.strip
    stripped2 = value2.to_s.strip
    similarity = if stripped1.empty? || stripped2.empty? || stripped1.size < 3 || stripped2.size < 3
      0.0
    else
      JAROW.getDistance(value1.downcase, value2.downcase)
    end

    similarity > options[:threshold]
  end

  def classify_hash(object1, object2)
    config.matchers.each_with_object({}) do |matcher, result|
      value1 = object1.send(matcher.property1)
      value2 = object2.send(matcher.property2)

      threshold = matcher.options[:threshold] || config.default_threshold || 0.0
      weight = matcher.options[:weight] || config.default_weight || 1.0

      score = (matcher.block || DEFAULT_MATCHER).call(value1, value2, threshold: threshold)
      result[[matcher.property1, matcher.property2]] = score * weight
    end
  end


end

