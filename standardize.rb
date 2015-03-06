require './config/environment'
require 'uri'

def twitter_username_from_url(url)
  match = url && url.match(/twitter.com\/([a-z0-9_]{1,15})\/?/i)
  match && match[1]
end

def github_username_from_url(url)
  url.scan(/github.com\/([a-z0-9\-]{1,39})\/?/i).map(&:last).sort_by(&:size)[0]
end

def uris_from_string(string)
  uri_strings = URI.extract(string, ['http', 'https'])
  uri_strings += string.scan(/\b[^\/\.\s]+\.[^\.\s]+\b/) # No protocol

  uri_strings -= uri_strings.map do |uri_string|
    uri_string.gsub(/^https?:\/\//, '')
  end

  uri_strings.uniq.map do |uri_string|
    uri_string.chop! if uri_string[-1] == ')'
    URI.parse(uri_string)
  end
end

def emails_from_string(string)
  string.scan(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}\b/)
end

query = Neo4j::Session.current.query

query.match(u: :User).set(u: {domains: nil, twitter_username: nil, uris: nil, usernames: nil, github_username: nil, emails: nil}).exec

StackOverflowUser.all.each do |user|
  user.twitter_username = twitter_username_from_url(user.website_url) || twitter_username_from_url(user.about_me)

  user.github_username = github_username_from_url(user.website_url) || github_username_from_url(user.about_me)

  user.uris = (uris_from_string(user.about_me) + uris_from_string(user.website_url)).map(&:to_s)

  user.emails = emails_from_string(user.about_me)

  user.domains = user.uris.map { |u| u.match(/^([^\/]+\/\/)?([^\/]+)/)[2] }
  user.domains += user.emails.map { |e| e.split('@')[1] }
  user.domains = user.domains.map { |d| d.gsub(/^www\./, '') }
  user.domains = user.domains.uniq.compact.map(&:downcase)

  user.usernames = user.emails.map { |e| e.split('@')[0] }
  user.usernames << user.display_name
  user.usernames << user.twitter_username
  user.usernames << user.github_username
  user.usernames = user.usernames.uniq.compact.map(&:downcase)

  user.save

  putc 's'
end

GitHubUser.all.each do |user|
  user.twitter_username = twitter_username_from_url(user.blog.to_s)

  user.usernames = [user.login]
  user.usernames << user.twitter_username
  user.usernames = user.usernames.uniq.compact.map(&:downcase)

  user.uris = uris_from_string(user.blog.to_s).map(&:to_s)

  user.domains = user.uris.map { |u| u.match(/^([^\/]+\/\/)?([^\/]+)/)[2] }
  user.domains = user.domains.map { |d| d.gsub(/^www\./, '') }
  user.domains = user.domains.uniq.map(&:downcase)

  user.save

  putc 'g'
end


COMMON_DOMAINS = query.match(u: :User).unwind(domain: 'u.domains').with(:domain, count: 'count(domain)').where('count > 1').pluck(:domain)
puts 'COMMON_DOMAINS', COMMON_DOMAINS.inspect

StackOverflowUser.all.each do |user|
  user.domains -= COMMON_DOMAINS
  user.save
  putc 's'
end

GitHubUser.all.each do |user|
  user.domains -= COMMON_DOMAINS
  user.save
  putc 'g'
end
