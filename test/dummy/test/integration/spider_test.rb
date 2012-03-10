require 'relevance/tarantula'
require 'test_helper'

class SpiderTest < ActionDispatch::IntegrationTest
  fixtures :all

  @@to_skip = [
    /^\/(posts|users)\/\d+(\/edit)?$/,
  ]

  def test_users
    t = tarantula_crawler(self)
    #t.handlers << Relevance::Tarantula::TidyHandler.new
    t.crawl_timeout = 15.seconds
    t.skip_uri_patterns += @@to_skip 
    t.crawl '/users'
  end

  def test_posts
    t = tarantula_crawler(self)
    #t.handlers << Relevance::Tarantula::TidyHandler.new
    t.crawl_timeout = 15.seconds
    t.skip_uri_patterns += @@to_skip 
    t.crawl '/posts'
  end

end
