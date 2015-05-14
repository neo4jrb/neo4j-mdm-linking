
class GitHubUser < GitHub
  self.mapped_label_name = 'User'

  id_property :id
  property :login
  property :avatar_url
  property :html_url
#  property :created_at
#  property :updated_at
  property :name
  property :location
  property :company
  property :blog
  property :email
  property :hierable, type: Boolean

  # Generated for standardization
  property :twitter_username
  property :uris

  property :domains
  property :uncommon_domains
  property :usernames

  # Human identified
  has_many :both, :identified_as, type: :IDENTIFIED, model_class: false

  # Store information about total score for matching between two nodes
  has_many :both, :computer_identified_as, type: :COMPUTER_IDENTIFIED, model_class: false

  # Store information amount match / score on individual property pairs
  # One relationship for each property pair
  has_many :both, :computer_identified_property_as, type: :COMPUTER_IDENTIFIED_PROPERTY, model_class: false

  def user_site_url
    self.html_url
  end
end

