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

def setup_demo_contact_list
  session[:contact_list] = { :friends => { katie: {phone: "914-772-8900", email: "katie@hotmail.com"}, emily: {phone: "671-890-7721", email: "emily@gmail.com"}},
                            :work => {kathy: {phone: "484-383-9028", email: "kathy@gmail.com"}},
                            :family => {patsy: {phone: "552-230-3390", email: "patsy@hotmail.com"}}
                          }
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

  @contact_list = setup_demo_contact_list

  erb :index
end

get "/:category/:name" do
  @category = params[:category].to_sym
  @name = params[:name].to_sym

  contact_info = session[:contact_list][@category][@name]
  @phone = contact_info[:phone]
  @email = contact_info[:email]
  erb :contact
end
