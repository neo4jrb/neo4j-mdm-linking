require 'faraday'
require 'faraday_middleware'
require 'active_support'
require 'neo4j'
require 'nokogiri'
require 'fuzzystringmatch'
require 'parallel'

faraday = Faraday.new(url: 'http://stackoverflow.com')

neo4j = Neo4j::Session.open(:server_db, 'http://localhost:7777')

neo4j.query('MATCH (u:User:StackOverflow) WHERE u.about_me IS NULL RETURN u').map(&:u).each do |user|
  puts "User ##{user.neo_id}"
  profile_link = user.props[:link]

  if profile_link
    html = faraday.get(profile_link) do |req|
      req.headers['Cookie'] = 'acct=t=tYLlCuLz05e5EiLo7oL%2bhvK1sK0B7Xf2&s=GDyNNozkIIDnp85TClyZFM5DiTxexF%2fl; gauth=gh7Ra+Cf2WIaoylsV5T2W8Qy+grLcFKZE+3kbB2lZqQ6iE19GBWPAyVR81X9QdwzfBapAfWPAtbxFU/nlx/HiIr+fZ182s9fDSNv/l21Wwo8XAFHRnQWIzgxMhUruuGawNWAcLKv8bfBlON/VvJYPzdIN36we8GGfoAt9fC6yoWTk++UNIWe9VUo+lhcXEPyHe/0srk3iKFDPfPdSPwqStrZW/ObBVXD+HgiNoKAcQ8J7gSodNVBOT0se6kHqazoJ0UWu/7UWy05uKZ58mxJdthKH+6t9347q0wW7qwkzis=:weXkVAAAAADhucr4avgltg==; usr=t=um0cdLFepUSB&s=Nvu0iuJGjEGr'
    end.body


    doc = Nokogiri::HTML(html)

    rows = doc.css('.data tr').map {|tr| tr.css('td').map(&:inner_text).map(&:strip) }.select {|row| row.size == 2 }
    data = Hash[*rows.flatten]

    about_me = doc.css('.user-about-me').inner_html
    email = data['email']
    website_url = data['website']
    location = data['location']
    age = data['age']

    neo4j.query('MATCH (u:User:StackOverflow) WHERE ID(u) = {user_id} SET u.about_me = {about_me}, u.email = {email}, u.website_url = {website_url}, u.location = {location}, u.age = {age}',
                user_id: user.neo_id, about_me: about_me, email: email, website_url: website_url, location: location, age: age)
  end
end




def twitter_username_from_url(url)
  match = url && url.match(/twitter.com\/([a-z0-9_]{1,15})/i)
  match && match[1]
end

puts "Setting twitter_usernames for users..."
neo4j.query('MATCH (u:User) RETURN u').map(&:u).each do |user|
  putc '.'

  twitter_username = twitter_username_from_url(user.props[:website_url]) ||
                     twitter_username_from_url(user.props[:blog]) ||
                      twitter_username_from_url(user.props[:about_me])

  if twitter_username
    puts
    puts "Setting user ##{user.neo_id} twitter_username = #{twitter_username}..."
    neo4j.query('MATCH (u) WHERE ID(u) = {user_id} SET u.twitter_username = {twitter_username}', user_id: user.neo_id, twitter_username: twitter_username.downcase)
  end
end

def standardize_url(url)
  url.to_s.downcase.gsub(/^https?:\/\//, '').gsub(/\/$/, '')
end

#puts
#puts 'Adding SAME_WEBSITE relationships...'
#
#neo4j.query('MATCH (u:User:GitHub) RETURN u').map(&:u).each do |github_user|
#  website_url = github_user.props[:blog]
#  next if website_url.blank?
#
#  website_url = standardize_url(website_url)
#
#  next if website_url.size <= 3
#  next if !website_url.match(/\./)
#  next if website_url.match(/^neo4j\.(org|com)/)
#
#  url_part = ".*#{website_url}.*"
#  params = {url_part: url_part, github_user_id: github_user.neo_id}
#
#  query = <<-QUERY
#  MATCH (ghu:User:GitHub), (sou:User:StackOverflow)
#               WHERE
#                 ID(ghu) = {github_user_id} AND
#                 (
#                   LOWER(sou.website_url) =~ {url_part} OR
#                   LOWER(sou.about_me) =~ {url_part}
#                 )
#              MERGE ghu-[:SAME_WEBSITE]->sou
#QUERY
#
#  neo4j.query(query, params) rescue nil
#end



def merge_relationship(neo4j, user1, user2, type, props = {})
  putc '-'
  neo4j.query.match(user1: :User, user2: :User).
              where(user1: {neo_id: user1.neo_id}, user2: {neo_id: user2.neo_id}).
              merge("user1-[rel:#{type.upcase}]->user2").
              break.
              set(rel: props).
              exec
end

JAROW = FuzzyStringMatch::JaroWinkler.create( :native )
MIN_LENGTH = 3

def string_similarity(string1, string2)
  stripped1 = string1.to_s.strip
  stripped2 = string2.to_s.strip
  if stripped1.empty? || stripped2.empty? || stripped1.size < MIN_LENGTH || stripped2.size < MIN_LENGTH
    0.0
  else
    JAROW.getDistance(string1.downcase, string2.downcase)
  end
end

puts
puts 'Going through all pairs...'
github_users = neo4j.query('MATCH (u:User:GitHub) RETURN u').map(&:u)
stackoverflow_users = neo4j.query('MATCH (u:User:StackOverflow) RETURN u').map(&:u)

#Parallel.each(github_users, in_processes: 3) do |github_user|
github_users.each do |github_user|
  putc '.'
  stackoverflow_users.each do |stackoverflow_user|
    github_props = github_user.props
    stackoverflow_props = stackoverflow_user.props

    name_similarity = string_similarity(github_props[:name], stackoverflow_props[:display_name])
    merge_relationship(neo4j, github_user, stackoverflow_user, 'REUSED_NAME', similarity: name_similarity) if name_similarity > 0.91

    login_similarity = string_similarity(github_props[:login], stackoverflow_props[:display_name])
    merge_relationship(neo4j, github_user, stackoverflow_user, 'REUSED_USERNAME', similarity: login_similarity) if login_similarity > 0.91

    location_similarity = string_similarity(github_props[:location], stackoverflow_props[:location])
    merge_relationship(neo4j, github_user, stackoverflow_user, 'REUSED_LOCATION', similarity: location_similarity) if location_similarity > 0.91

    if stackoverflow_props[:about_me].match(/github\.com\/#{github_props[:login]}/)
      merge_relationship(neo4j, github_user, stackoverflow_user, 'REUSED_USERNAME', similarity: 1.0, login_in_about_me: true)
    end

    if stackoverflow_props[:website_url].match(/github\.com\/#{github_props[:login]}/)
      merge_relationship(neo4j, github_user, stackoverflow_user, 'REUSED_USERNAME', similarity: 1.0, login_in_website_url: true)
    end

    url_similarity = string_similarity(standardize_url(github_props[:blog]), standardize_url(stackoverflow_props[:website_url]))
    merge_relationship(neo4j, github_user, stackoverflow_user, 'SAME_WEBSITE', similarity: url_similarity) if url_similarity > 0.93

  end
end
