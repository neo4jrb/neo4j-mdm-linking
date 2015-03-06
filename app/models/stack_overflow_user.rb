class StackOverflowUser < StackOverflow
  self.mapped_label_name = 'User'

  include User

  id_property :user_id
  property :link
  property :display_name
  property :profile_image
  property :user_type
  property :reputation, type: Integer
  property :accept_rate, type: Integer
  property :about_me
  property :website_url
  property :location
  property :age, type: Integer

  # Generated for standardization
  property :twitter_username
  property :github_username
  property :uris
  property :emails

  property :domains
  property :usernames
  
  has_many :both, :identified_as, type: :IDENTIFIED, model_class: false

  has_many :both, :computer_identified_as, type: :COMPUTER_IDENTIFIED, model_class: false
end


