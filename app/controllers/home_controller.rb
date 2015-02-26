class HomeController < ApplicationController
  def index
    @data = query.match('(ghu:User:GitHub)-[rel]-(sou:User:StackOverflow)').order('length(collect(rel)) DESC').limit(100).pluck('DISTINCT ghu, collect(rel), sou')
  end

  def sample
    @github_user, @stackoverflow_user = get_unrated_sample_pair

    user_query = query.match('(sou:User:StackOverflow)').where(sou: {neo_id: @stackoverflow_user.neo_id})

    stackoverflow_question_ids = user_query.match('sou-[:ASKED]->(question:Question)').pluck(question: :question_id)
    stackoverflow_question_ids += user_query.match('sou-[:PROVIDED]->(:Answer)-[:ANSWERS]->(question:Question)').pluck(question: :question_id)

    @stackoverflow_tags = query.match('(question:Question)<-[:TAGS]-(tag:Tag)').where(question: {question_id: stackoverflow_question_ids}).pluck(tag: :text).counts

    @github_repos = query.match('(ghu:User:GitHub)<-[:HAS_OWNER]-(repo:Repository)').where(ghu: {neo_id: @github_user.neo_id}).pluck(repo: :full_name)
    @github_languages = query.match('(repo:Repository)-[rel:USES_LANGUAGE]->(language:Language)').
                                             where(repo: {full_name: @github_repos}).
                                             pluck(language: :name, rel: :byte_count).each_with_object({}) do |(language, byte_count), result|
                                               result[language] ||= 0
                                               result[language] += byte_count.to_i
                                             end
  end

  def get_unrated_sample_pair
    github_user, stackoverflow_user, _ = get_sample_pair
    while pair_identified?(github_user, stackoverflow_user)
      github_user, stackoverflow_user, _ = get_sample_pair
    end
    [github_user, stackoverflow_user]
  end

  def pair_identified?(user1, user2)
    query.match('(user1:User)-[rel:IDENTIFIED]-(user2:User)').
      where(user1: {neo_id: user1.neo_id}, user2: {neo_id: user2.neo_id}).
      pluck('count(*)').first > 0
  end

  def get_sample_pair
    if rand > 0.2
      query.match('(ghu:User:GitHub)-[rel]-(sou:User:StackOverflow)').
                                  with(:ghu, :sou, rel_count: 'count(rel)').
                                  break.
                                  where('rel_count >= 2').
                                  with(:ghu, :sou, index: 'rand()').order('index').limit(1).
                                  pluck('DISTINCT ghu, sou, index').first
    else
      github_user, _ = query.match('(ghu:User:GitHub)').with(:ghu, index: 'rand()').order('index').limit(1).pluck(:ghu).first
      stackoverflow_user, _ = query.match('(sou:User:StackOverflow)').with(:sou, index: 'rand()').order('index').limit(1).pluck(:sou).first

      [github_user, stackoverflow_user, rand]
    end
  end

  def identify
    query.match('(ghu:User:GitHub),(sou:User:StackOverflow)').
                               where(ghu: {neo_id: params[:user1]}, sou: {neo_id: params[:user2]}).
                               merge('ghu-[rel:IDENTIFIED]-sou').break.set(rel: {index: params[:index]}).
                               exec

    redirect_to action: :sample
  end

  def query
    Neo4j::Session.query
  end
end
