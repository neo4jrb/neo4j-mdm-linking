require './config/environment'
require './lib/github_stackoverflow_identifier'


identifier = GithubStackoverflowIdentifier.new

StackOverflowUser.first # Load model class to get past bug

ghus = GitHubUser.all.to_a
sous = StackOverflowUser.all.to_a

Neo4j::Session.current.query("MATCH (ghu:GitHub:User)-[rel:COMPUTER_IDENTIFIED]-(sou:StackOverflow:User) DELETE rel")
Neo4j::Session.current.query("MATCH (ghu:GitHub:User)-[rel:COMPUTER_IDENTIFIED_PROPERTY]-(sou:StackOverflow:User) DELETE rel")

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
    hash.each do |key, value|
      ghu.computer_identified_property_as.create(sou, score: value, source_property: key[0].to_s, target_property: key[1].to_s) if value > 0.0
    end
  end

  putc 'g'
end

