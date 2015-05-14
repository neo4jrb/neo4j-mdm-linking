require './config/environment'
require './lib/github_stackoverflow_identifier'
require './lib/stats'

StackOverflowUser.first # Load model class to get past bug

properties = GitHubUser.as(:ghu).computer_identified_property_as(:sou, :rel).pluck('DISTINCT rel.source_property, rel.target_property')



result = GitHubUser.as(:ghu).computer_identified_property_as(:sou, :rel).query.
    optional_match('ghu-[i:IDENTIFIED]-sou').
    pluck('ID(ghu), ID(sou), rel.source_property, rel.target_property, rel.score, toInt(i.index)')

$x_and_y_query_data = result.map {|row| row[2, 4] }

def x_and_y_from_weights(weights)
  x = []
  y = []

  $x_and_y_query_data.each do |source_property, target_property, rel_score, human_index|
    x << (rel_score * weights[[source_property, target_property]])

    y << human_index
  end

  [x, y]
end

data = []
0.5.step(5.0, 1.0).to_a.repeated_combination(9).lazy.each do |combination|
  index = 0
  weights = properties.each_with_object({}) do |(source_property, target_property), result|
    result[[source_property, target_property]] = combination[index]
    index += 1
  end

  x, y = x_and_y_from_weights(weights)
#  puts 'weights', weights.inspect
#  puts 'pearson_correlation', pearson_correlation(x, y)

#  x_scale = x.to_scale
#  y_scale = y.to_scale

  putc '.'
  max_x = x.max
  1.step(max_x.ceil, 1.0).to_a.map do |threshold|
    precision, recall = precision_and_recall(x, y, threshold) do |i, j|
      match = i > threshold ? true : false

      status = case j
      when 1, 2
        :match
      when 0
        :ask
      when -1, 2
        :no_match
      end
    end


    if !precision.nan? && !recall.nan? && (precision + recall) > 1.9
      item = {
        weights: weights,
  #      corr: Statsample::Bivariate::Pearson.new(x_scale, y_scale).r,
        threshold: threshold,
        precision: precision,
        recall: recall
      }

      puts
      puts item.inspect

      data << item
    end
  end
end

require 'pry'
binding.pry

