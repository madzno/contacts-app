require "sinatra"
require "sinatra/reloader"
require "sinatra/content_for"
require "tilt/erubis"
require "yaml"
require "bcrypt"

configure do
  enable :sessions
  set :session_secret, "ecd8395e28623aad9ac3053dfc47dbeff10971c0db59deaba5e0acada1939451"
end

before do
  session[:contact_list] || session[:contact_list] = {:friends => {}, :work => {}, :family => {}}
end

def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
  YAML.load_file(credentials_path)
end

def valid_credentials?(username, password)
  credentials = load_user_credentials

  if credentials.key?(username)
    bcrypt_password = BCrypt::Password.new(credentials[username])
    bcrypt_password == password
  else
    false
  end
end

def user_signed_in?
  session.key?(:username)
end

def require_signed_in_user
  unless user_signed_in?
    session[:message] = "You must be signed in to do that."
    redirect "/"
  end
end

get "/" do
  erb :home
end

get "/signin" do
  erb :signin
end

post "/signin" do
  username = params[:username]

  if valid_credentials?(username, params[:password])
    session[:username] = params[:username]
    session[:message] = "Welcome #{username}!"
    redirect "/"
  else
    session[:message] = "Invalid Credentials"
    status 422
    erb :home
  end
end

post "/signout" do
  session.delete(:username)
  session[:message] = "You have been signed out."
  redirect "/"
end

get "/index" do
  require_signed_in_user

  @contact_list = session[:contact_list]

  erb :index
end

get "/contact/new" do
  require_signed_in_user

  erb :new_contact
end

post "/contact/new" do
  require_signed_in_user

  name = params[:name].to_sym
  category = params[:category].to_sym
  phone = params[:phone]
  email = params[:email]

  @contact_list = session[:contact_list]
  @contact_list[category][name] = {phone: phone, email: email}

  redirect "/index"
end

get "/:category/:name" do
  require_signed_in_user

  @category = params[:category].to_sym
  @name = params[:name].to_sym

  contact_info = session[:contact_list][@category][@name]
  @phone = contact_info[:phone]
  @email = contact_info[:email]
  erb :contact
end
