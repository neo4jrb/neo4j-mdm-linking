
def precision_and_recall(x, y, threshold)
  true_positives = 0
  false_positives = 0
  false_negatives = 0
  true_negatives = 0

  x.each_with_index do |i, index|
    match = yield i, y[index]

    if match
      case status
      when :match
        true_positives += 1
      when :ask
      when :no_match
        false_positives += 1
      end
    else
      case status
      when :match
        false_negatives += 1
      when :ask
      when :no_match
        true_negatives += 1
      end
    end
  end

  precision = true_positives.to_f / (true_positives + false_positives).to_f

  recall =  true_positives.to_f / (true_positives + false_negatives).to_f

  [precision, recall]
end

def pearson_correlation(x, y)
  Statsample::Bivariate::Pearson.new(x.to_scale, y.to_scale).r
end
