module ApplicationHelper
  def httpize(url)
    "http://#{url}" unless url.try(:match, '//')
  end
end
