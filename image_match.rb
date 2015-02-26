require 'neo4j'
require 'phashion'
require 'open-uri'
require 'parallel'

neo4j = Neo4j::Session.open(:server_db, 'http://localhost:7777')

def images_for(site)
  Dir.glob("avatars/#{site}/*").select do |path|
    File.size(path) > 0
  end.map do |path|
    [path, Phashion::Image.new(path)]
  end
end

Parallel.each(images_for(:github), :in_processes=>4) do |github_avatar_path, github_img|
  putc '-'
  images_for(:stackoverflow).each do |stackoverflow_avatar_path, stackoverflow_img|
    begin
    if github_img.duplicate? stackoverflow_img
      puts
      puts "#{github_avatar_path} SAME AS #{stackoverflow_avatar_path}"

      stackoverflow_user_id = File.basename(stackoverflow_avatar_path)
      github_login = File.basename(github_avatar_path)

      params = {
        stackoverflow_user_id: stackoverflow_user_id.to_i,
        github_login: github_login,
        distance: github_img.distance_from(stackoverflow_img)
      }
      puts 'params', params.inspect

      neo4j.query("MATCH
                    (sou:User:StackOverflow {user_id: {stackoverflow_user_id}}),
                    (ghu:User:GitHub {login: {github_login}})
                  MERGE sou-[r:SIMILAR_IMAGE_TO]->ghu
                  SET r.distance = {distance}", params)

    end
    rescue => e
      raise e unless e.message == 'Unknown pHash error'
    end
  end
end
