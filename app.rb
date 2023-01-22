# frozen_string_literal: true

require 'sinatra'
require 'sinatra/reloader' if development?
require 'tilt/erubis'
require 'sinatra/content_for'

configure do
end

before do
end

helpers do
end

get "/" do
  erb :index
end
