require 'sinatra'
require 'sinatra/reloader'
require 'json'
require 'securerandom'

use Rack::Session::Cookie, key: 'rack.session',
        path: '/',
        secret: SecureRandom.hex(64)

configure do
  enable :sessions
end

ARTICLES_FILE = 'articles.json'
COMMENTS_FILE = 'comments.json'

get '/article' do
  @articles = load_articles_from_file.sort_by { |article| article[:created_at] }.reverse
  erb :article
end

get '/' do
  erb :index
end

post '/article' do
  if params[:password] && params[:message]
    new_article = { password: params[:password], message: params[:message] }
    save_article_to_file(new_article)
    redirect back
  else
    redirect '/post_article'
  end
end

get '/search' do
  query = params[:query]
  @articles = search_articles(query).reverse
  erb :search_results
end

def search_articles(query)
  articles = load_articles_from_file
  articles.select do |article|
    article[:password].include?(query) || article[:message].include?(query)
  end
end

get '/post_article' do
  erb :post_article
end

get '/full_article/:id' do
  @id = params[:id]
  @article = load_article_by_password(@id)
  @comments = load_comments_for_article(@id).reverse
  erb :full_article
end

post '/comment' do
  if params[:author] && params[:content] && params[:article_id]
    new_comment = {
      author: params[:author],
      content: params[:content],
      article_id: params[:article_id]
    }
    save_comment_to_file(new_comment)
    redirect "/full_article/#{params[:article_id]}"
  else
    redirect '/'
  end
end

helpers do
  def delete_article(article_id)
    articles = load_articles_from_file
    articles.reject! { |article| article[:password] == article_id }
    File.write(ARTICLES_FILE, articles.to_json)
  end

  def delete_comments_for_article(article_id)
    comments = load_comments_from_file
    comments.reject! { |comment| comment[:article_id] == article_id }
    File.write(COMMENTS_FILE, comments.to_json)
  end

  def load_articles_from_file
    if File.exist?(ARTICLES_FILE)
      articles = JSON.parse(File.read(ARTICLES_FILE), symbolize_names: true)
      articles.sort_by { |article| article[:created_at] }.reverse
    else
      []
    end
  end

  def save_article_to_file(article)
    articles = load_articles_from_file
    articles.unshift(article)
    File.write(ARTICLES_FILE, articles.to_json)
  end

  def load_comments_from_file
    if File.exist?(COMMENTS_FILE)
      JSON.parse(File.read(COMMENTS_FILE), symbolize_names: true)
    else
      []
    end
  end

  def save_comment_to_file(comment)
    comments = load_comments_from_file
    comments.push(comment)
    File.write(COMMENTS_FILE, comments.to_json)
  end
end

def load_article_by_password(password)
  articles = load_articles_from_file
  articles.detect { |article| article[:password] == password }
end

def load_comments_for_article(password)
  comments = load_comments_from_file
  comments.select { |comment| comment[:article_id] == password }
end

get '/setumei' do
  erb :setumei
end

before do
  session[:new_article] ||= {}
end

post '/article' do
  if params[:password] && params[:message]
    session[:new_article] = { password: params[:password], message: params[:message] }
    redirect '/confirm_article'
  else
    redirect '/post_article'
  end
end

get '/confirm_article' do
  @new_article = session[:new_article]
  erb :confirm_article
end

post '/confirm_article' do
  if session[:new_article]
    new_article = session[:new_article]
    save_article_to_file(new_article)
    session[:new_article] = {}
    redirect '/article'
  else
    redirect '/post_article'
  end
end

get '/lock' do
  erb :locl
end

delete '/delete_article/:id' do
  article_id = params[:id]
  delete_article(article_id)
  delete_comments_for_article(article_id)
  redirect '/article'
end
