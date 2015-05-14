famous_neo4j_github_logins = %w(
  jexp
  sarmbruster
  maxdemarzi
  peterneubauer
  ikwattro
  wfreeman
  moxious
  mneedham
  subvertallchris
  cheerfulstoic
  pombredanne
  nawroth
  akollegger
  thobe
  jakewins
  simpsonjulian
  andreasronge
  tbaum
)

famous_neo4j_stackoverflow_user_ids = %w(
  2920686
  232671
  4187346
  974731
  2061244
  2481199
  256108
  272109
)

# A maximum set of weights found from find_weights_with_neo.rb
weights = {
  ["login", "display_name"]=>1.5,
  ["name", "display_name"]=>1.5,
  ["location", "location"]=>3.5,
  ["usernames", "usernames"]=>3.5,
  ["uncommon_domains", "uncommon_domains"]=>4.5,
  ["blog", "website_url"]=>4.5,
  ["neo_id", "neo_id"]=>4.5,
  ["login", "github_username"]=>4.5,
  ["twitter_username", "twitter_username"]=>4.5
}

# frobberofbits ??
# https://twitter.com/mdavidallen

users = StackOverflowUser.where(user_id: famous_neo4j_stackoverflow_user_ids.map(&:to_i)).to_a

users += GitHubUser.where(login: famous_neo4j_github_logins).to_a

#puts '| | ' + weights.keys.map {|ghp, sop| ghp if ghp != sop }.join(' | ')
#puts '| User | ' + weights.keys.map {|ghp, sop| sop }.join(' | ')
#puts '|----------------------------'

dat_file = File.open('famous_peeps.dat', 'w')
dat_file << weights.keys.map {|ghp, sop| '"' + [ghp, sop].compact.uniq.join(' / ') + '"' }.join("\t") + "\n"

data = []
users.each do |user|
  other_user, rels = user.computer_identified_property_as(:other_user, :rel).pluck(:other_user, 'collect(rel)').first

  rels_by_properties = (rels || []).index_by {|rel| [rel.props[:source_property], rel.props[:target_property]] }

  ghu, sou = (user.respond_to?(:login) ? [user, other_user] : [other_user, user])

  row = [
    ((sou ? sou.display_name : ghu.login) + ' ' + [(ghu && "[GH](#{ghu.user_site_url})"), (sou && "[SO](#{sou.user_site_url})")].compact.join(' ')).gsub(/\s/, '&nbsp;')
  ]
  dat_row = [ghu ? ghu.login : sou.display_name]

  weights.each do |(source, target), weight|
    rel = rels_by_properties[[source, target]]
    weight = weights[[source, target]]

    d = ((rel ? rel.props[:score] : 0.0) * weight).round(1)
    row << d
    dat_row << d
  end

  #puts "|" + row.join(' | ')


  puts '| GH Prop | SO Prop | GH Value | SO Value | Weight | Base Score | Weighted Score |'
  puts '|----------------------------'

  weights.each do |(source, target), weight|
    rel = rels_by_properties[[source, target]]
    weight = weights[[source, target]]

    property_desc = -> (prop) { prop == 'neo_id' ? 'image_comparison' : prop }

    puts "| #{property_desc.call(source)} | #{property_desc.call(target)} | #{ghu && ghu.send(source)} | #{sou && sou.send(target)} | #{weight} | #{(rel ? rel.props[:score] : 0).round(2)} | #{((rel ? rel.props[:score] : 0.0) * weight).round(1)} |"
  end


  puts
  puts
  puts

  dat_file << dat_row.join("\t") + "\n"

  data << row
end

# 3-4 github and so users each with different matching criterias and show how they each are processed, matched, scored in each step


