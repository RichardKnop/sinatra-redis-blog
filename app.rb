# 'sinatra'
require 'bundler'

Bundler.require

r = Redis.new

class Repo
  attr_reader :db

  def initialize
    @db = Redis.new
  end
  
  def get key
    data = db.hgetall(key)
    obj = klazz.new(data)
    obj.id = key
    obj
  end

  def get_all
    result = []
    keys.sort.each do |key|
      result << get(key)
    end
    result
  end

  def delete key
    raise "#{klazz} does not exists" unless keys.include? key
    db.del(key)
  end 

  def store obj
    if obj.id 
      db.hmset(obj.id, *(obj.as_hash.to_a))
    else 
      obj.id = generate_key
      db.hmset(obj.id, *(obj.as_hash.to_a))
    end
  end

private

  def keys
    db.keys("#{prefix}:*")
  end

  def generate_key
    last_key = keys.sort.last || "#{prefix}:0"
    index = last_key.split(':').last.to_i
    "#{prefix}:#{index + 1}"
  end

  def prefix
    raise "prefix not set"
  end

  def klazz
    raise "needs data access class"
  end
end

class Dao
  attr_accessor :id
  def self.properties *args
    args.each do |arg|
      keys << arg.to_sym
      attr_accessor arg.to_sym
    end
  end

  def self.keys
    @keys ||= []
  end

  def initialize(properties = {})
    update(properties)
  end

  def update properties = {}
    properties.each do |key, val|
      key = key.to_sym
      raise "Property not allowed: #{key}" unless self.class.keys.include? key
      send("#{key}=".to_sym, val)
    end
  end

  def as_hash
    h = {}
    self.class.keys.each do |key|
      h[key.to_s] = send(key)
    end
    h
  end
end

class Post < Dao
  properties :title, :content
end

class PostRepo < Repo
  def prefix
    "post"
  end

  def klazz
    Post
  end
end

get '/' do
  @posts = PostRepo.new.get_all
  haml :index
end

get '/posts/new' do 
  @post = Post.new
  haml :new
end

post '/posts' do 
  @post = Post.new(params['post'])
  PostRepo.new.store(@post)
  redirect to('/')
end

get '/posts/:id' do |id|
  @post = PostRepo.new.get(id)
  haml :show
end

get '/posts/:id/edit' do |id|
  @post = PostRepo.new.get(id)
  haml :edit
end

put '/posts/:id' do |id|
  @post = PostRepo.new.get(id)
  @post.update(params['post'])
  PostRepo.new.store(@post)
  redirect to("/posts/#{@post.id}")
end

get '/posts/:id/delete' do |id|
  PostRepo.new.delete(id)
  redirect to('/')
end
