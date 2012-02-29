class Post < ActiveRecord::Base
  belongs_to :user
  def self.search(q)
    return where('posts.title LIKE :q OR posts.body LIKE :q', {:q => "%#{q}%"})
  end
end
