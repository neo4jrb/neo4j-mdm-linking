require 'ostruct'
require 'open3'
require './lib/stats'

def from_json(string)
  JSON.parse(string).tap do |data|
    data.keys.each do |key|
      data[eval(key)] = data.delete(key)
    end
  end
end

data = GitHubUser.as(:ghu).optional(:computer_identified_as, :sou, :ci).query.optional_match("ghu-[i:IDENTIFIED]-sou").pluck(:ci, :i).map do |ci, i|
  score_data = from_json(ci.props[:hash])

  {
    score_data: score_data,
    human_score: i.props[:index].to_i
  }
end

keys = data.first[:score_data].keys

y = data.map {|datum| datum[:human_score] }

def x_for_weights(weights, data)
  data.map do |datum|
    datum[:score_data].inject(0) do |score, (key, value)|
      score + weights[key] * value
    end
  end
end

results = []
1000.times do |i|
  weights = keys.each_with_object({}) do |key, result|
    result[key] = (rand * 5.0)
  end

  x = x_for_weights(weights, data)

  results << OpenStruct.new(weights: weights, corr: pearson_correlation(x, y).abs, x: x, y: y)
end


result_results = []

results.sort_by(&:corr).reverse[0,100].each_with_index do |result, i|
  x = result.x
  y = result.y

  1.step(15,0.25).to_a.map do |threshold|

    x = x_for_weights(result.weights, data)

    a = precision_and_recall(x, y, threshold)
    score_score = a[0] + a[1]

    result_results << [score_score, result.weights, threshold]
  end

end

require 'pry'
binding.pry

score_score, weights, threshold = result_results.reject {|a| a.first.nan? }.sort_by(&:first)[-1]
x = x_for_weights(weights, data)

gnuplot_commands = <<"End"
  set terminal png
  set output "plot.png"
  set xrange [-2.5:2.5]
  set yrange [0:#{x.max}]
  plot "-" with points
End

x.each_with_index do |x_i, i|
  gnuplot_commands << "#{y[i]} #{x_i}\n"
end; 1

gnuplot_commands << "e\n"; 1

Open3.capture2("gnuplot", :stdin_data=>gnuplot_commands, :binmode=>true)

File.open("weights.json", 'w') do |f|
  f << weights.to_json
end

