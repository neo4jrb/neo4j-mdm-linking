require './config/environment'
require './lib/object_identifier'

JAROW = FuzzyStringMatch::JaroWinkler.create( :native )

exact_string_matcher = proc do |value1, value2|
  value1 = value1.to_s.strip.downcase
  value2 = value2.to_s.strip.downcase
  (value1.size >= 1 && value1 == value2) ? 1.0 : 0.0
end

fuzzy_string_matcher = proc do |value1, value2, options = {}|
  stripped1 = value1.to_s.strip
  stripped2 = value2.to_s.strip
  if stripped1.empty? || stripped2.empty? || stripped1.size < 3 || stripped2.size < 3
    0.0
  else
    score = JAROW.getDistance(value1.downcase, value2.downcase)
    score > options[:threshold] ? score : 0
  end
end

def array_matcher(single_matcher, array1, array2, options = {})
  array1.map do |value1|
    array2.map do |value2|
      single_matcher.call(value1, value2, options)
    end
  end.flatten.sum
end

array_fuzzy_string_matcher = proc do |array1, array2, options = {}|
  array_matcher(fuzzy_string_matcher, array1, array2, options)
end

array_exact_string_matcher = proc do |array1, array2, options = {}|
  array_matcher(exact_string_matcher, array1, array2, options)
end

IMAGE_SIMILARITIES = {}

query = Neo4j::Session.current.query

query.match(u1: :User, u2: :User).match('u1-[rel:COMPUTER_IDENTIFIED]-u2').delete(:rel).exec

query.match('(sou:StackOverflow:User)-[r:SIMILAR_IMAGE_TO]->(ghu:GitHub:User)').pluck('ID(sou), r.distance, ID(ghu)').each do |sou_id, distance, ghu_id|
  score = (15.0 - distance) / 15.0

  IMAGE_SIMILARITIES[[sou_id, ghu_id]] = score
  IMAGE_SIMILARITIES[[ghu_id, sou_id]] = score
end

identifier = ObjectIdentifier.new do |config|
  config.default_threshold = 0.75
  config.default_weight = 1.0

  config.add_matcher :name, :display_name, &fuzzy_string_matcher
  config.add_matcher :login, :display_name, &fuzzy_string_matcher
  config.add_matcher :blog, :website_url, &fuzzy_string_matcher
  config.add_matcher :location, :location, &fuzzy_string_matcher

  config.add_matcher :login, :github_username, &exact_string_matcher
  config.add_matcher :twitter_username, :twitter_username, &exact_string_matcher

  config.add_matcher :domains, :domains, threshold: 0.97, &array_fuzzy_string_matcher
  config.add_matcher :usernames, :usernames, threshold: 0.97, &array_exact_string_matcher

  config.add_matcher(:neo_id, :neo_id, threshold: 0.7) do |neo_id1, neo_id2, options = {}|
    score = IMAGE_SIMILARITIES[[neo_id1, neo_id2]] || 0.0

    score > options[:threshold] ? score : 0
  end
end

StackOverflowUser.first # Load model class to get past bug

ghus = GitHubUser.all.to_a
sous = StackOverflowUser.all.to_a

ghus.each do |ghu|
#  a = Parallel.map(sous, in_processes: 4) do |sou|
  a = sous.map do |sou|
    hash = identifier.classify_hash(ghu, sou)
    score = hash.values.sum

    [sou, score, hash] if score >= 1.5
  end

  a.compact.each do |sou, score, hash|
    putc '!'
    ghu.computer_identified_as.create(sou, score: score, hash: hash.to_json)
  end

  putc 'g'
end
