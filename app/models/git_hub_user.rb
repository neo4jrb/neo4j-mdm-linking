
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
  property :usernames

  has_many :both, :identified_as, type: :IDENTIFIED, model_class: false

  has_many :both, :computer_identified_as, type: :COMPUTER_IDENTIFIED, model_class: false
end

