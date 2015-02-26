require 'neo4j'
require 'phashion'
require 'open-uri'
require 'parallel'

neo4j = Neo4j::Session.open(:server_db, 'http://localhost:7777')

site_label = 'GitHub'
id_field = :login
url_field = :avatar_url

site_label = 'StackOverflow'
id_field = :user_id
url_field = :profile_image



users = neo4j.query("MATCH (u:User:#{site_label}) WHERE u.#{url_field} IS NOT NULL RETURN u").map(&:u)

Parallel.each(users, in_processes: 8) do |user|
  if File.exist?("./avatars/#{site_label.downcase}/#{user.props[id_field]}")
    putc '-'
  else
    putc '.'
    `curl "#{user.props[url_field]}" > ./avatars/#{site_label.downcase}/#{user.props[id_field].to_s.downcase}`
  end
end



