# frozen_string_literal: true

require 'sinatra'
require 'sinatra/reloader' if development?
require 'tilt/erubis'
require 'sinatra/content_for'
require 'redcarpet'
require 'yaml'
require 'bcrypt'

# global methods
def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def signed_in?
  session[:login_status] == true
end

def require_signed_in
  unless signed_in?
    session[:error] = "You must be signed in to do that."
    redirect "/"
  end
end

def correct_credentials?(name,pw)
  if ENV["RACK_ENV"] == "test"
    accounts = YAML.load_file("test/users.yaml")
  else
    accounts = YAML.load_file("users.yaml")
  end
  BCrypt::Password.new(accounts[name]) == pw
end

def sign_in(username)
  session[:login_status] = true
  session[:username] = username
end

def sign_out
  session[:login_status] = false
  session[:username] = nil
end

# routes
configure do
  enable :sessions
  set :session_secret, 'afb00d68fbae86e81ff2fe04c3206bba5f0c4165401c3d1bf3e8fdbe222d2081'
end

before do
  @files = Dir.glob(data_path + "/*").map do |path|
    File.basename(path)
  end
end

helpers do
  def m(str)
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    markdown.render(str)
  end
end

get "/" do
  if signed_in?
    @username = session[:username]
    erb :index
  else
    status 302
    redirect "/signin"
  end
end

get "/signin" do
  erb :sign_in
end

post "/signin" do
  if correct_credentials?(params[:username], params[:pw])
    sign_in(params[:username])
    session[:success] = "Welcome!"
    redirect "/"
  else
    status 422
    session[:error] = "Invalid credentials"
    @username = params[:username]
    erb :sign_in
  end
end

post "/signout" do
  sign_out
  session[:success] = "You have been signed out."
  redirect "/signin"
end

get "/new" do
  require_signed_in

  erb :new
end

post "/new" do
  require_signed_in

  if params[:file_name].nil? || params[:file_name].strip.empty?
    session[:error] = "A name is required."
    status 422
    erb :new
  else
    @file_name = params[:file_name]
    if File.write("#{data_path}/#{@file_name}", "")
      session[:success] = "#{@file_name} has been created."
    end
    redirect "/"
  end
end

get "/:file_name" do
  require_signed_in

  if File.exist?("#{data_path}/#{params[:file_name]}")
    text = File.read("#{data_path}/#{params[:file_name]}")
    if params[:file_name][-3, 3] == 'txt'
      [200, {"Content-Type" => "text/plain"}, [text]]
    else
      erb m(text)
    end
  else
    session[:error] = "#{params[:file_name]} does not exist."
    redirect "/"
  end
end

get "/:file_name/edit" do
  require_signed_in

  @file_name = params[:file_name]
  @contents = File.read("data/#{@file_name}")
  erb :edit
end

post "/:file_name/save" do
  require_signed_in

  @file_name = params[:file_name]
  @contents = params[:contents] || ""
  if File.write("#{data_path}/#{@file_name}", @contents)
    session[:success] = "#{@file_name} has been updated."
  end
  redirect "/"
end

post "/:file_name/delete" do
  require_signed_in

  if session[:login_status] == false
    status 302
    session[:error] = "You must be signed in to do that."
    redirect "/"
  end
  file_name = params[:file_name]
  if File.delete("#{data_path}/#{file_name}")
    session[:success] = "#{file_name} was deleted."
  end
  redirect "/"
end
