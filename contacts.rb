require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/content_for'
require 'tilt/erubis'
require 'yaml'
require 'bcrypt'

configure do
  enable :sessions
  set :session_secret, ENV.fetch('SESSION_SECRET') {SecureRandom.hex(64)}
  set :erb, :escape_html => true
end

before do
  session[:contact_list] || session[:contact_list] = { :friends => {}, :work => {}, :family => {} }
end

helpers do
  def has_contacts?(category)
    !session[:contact_list][category].empty?
  end
end

def load_user_credentials
  credentials_path = if ENV['RACK_ENV'] == 'test'
                       File.expand_path('../test/users.yml', __FILE__)
                     else
                       File.expand_path('../users.yml', __FILE__)
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
    session[:message] = 'You must be signed in to do that.'
    redirect '/'
  end
end

def error_for_new_contact(category, name, phone, email)
  if !(1..100).cover?(name.strip.size)
    'Contact name must be between 1 and 100 characters.'
  elsif session[:contact_list][category].key?(name.to_sym)
    'Contact name must be unique.'
  elsif !valid_phone_number?(phone)
    'Please enter a valid 10 digit phone number in the format: XXX-XXX-XXXX'
  elsif !valid_email?(email)
    'Please enter a valid email address.'
  end
end

def valid_phone_number?(phone)
  phone.match?(/[0-9]{3}-[0-9]{3}-[0-9]{4}/)
end

def valid_email?(email)
  email.include?('@')
end

get '/' do
  erb :home
end

get '/signin' do
  erb :signin
end

post '/signin' do
  username = params[:username]

  if valid_credentials?(username, params[:password])
    session[:username] = params[:username]
    session[:message] = "Welcome #{username}!"
    redirect '/'
  else
    session[:message] = 'Invalid Credentials'
    status 422
    erb :signin
  end
end

post '/signout' do
  session.delete(:username)
  session[:message] = 'You have been signed out.'
  redirect '/'
end

get '/index' do
  require_signed_in_user

  @contact_list = session[:contact_list]

  erb :index
end

get '/contact/new' do
  require_signed_in_user

  erb :new_contact
end

post '/contact/new' do
  require_signed_in_user

  category = params[:category].to_sym
  name = params[:name]
  new_phone = params[:phone]
  new_email = params[:email]

  error = error_for_new_contact(category, name, new_phone, new_email)

  if error
    session[:message] = error
    status 422
    erb :new_contact
  else
    @contact_list = session[:contact_list]
    @contact_list[category][name.to_sym] = { phone: new_phone, email: new_email }
    redirect '/index'
  end
end

post '/index/:category/:name/delete' do
  require_signed_in_user

  category = params[:category].to_sym
  name = params[:name].to_sym
  contact_list = session[:contact_list]

  contact_list[category].delete(name)

  session[:message] = "Contact information for #{name.capitalize} deleted."

  redirect "/index"
end

get "/:category/:name/edit" do
  require_signed_in_user

  @category = params[:category].to_sym
  @name = params[:name].to_sym
  @current_phone = session[:contact_list][@category][@name][:phone]
  @current_email = session[:contact_list][@category][@name][:email]

  erb :edit_contact
end

post "/:category/:name/edit" do
  require_signed_in_user

  @category = params[:category].to_sym
  @name = params[:name].to_sym
  @current_phone = session[:contact_list][@category][@name][:phone]
  @current_email = session[:contact_list][@category][@name][:email]

  contact_info = session[:contact_list][@category][@name]

  if params[:phone] && !valid_phone_number?(params[:phone])
    session[:message] = 'Please enter a valid 10 digit phone number in the format: XXX-XXX-XXXX'
    status 422
    erb :edit_contact
  elsif params[:email] && !valid_email?(params[:email])
    session[:message] = 'Please enter a valid email address.'
    status 422
    erb :edit_contact
  elsif params[:phone] && valid_phone_number?(params[:phone])
    contact_info[:phone] = params[:phone]
    session[:message] = "#{@name.capitalize}'s phone updated."
    redirect "/#{@category}/#{@name}/edit"
  elsif params[:email] && valid_email?(params[:email])
    contact_info[:email] = params[:email]
    session[:message] = "#{@name.capitalize}'s email updated."
    redirect "/#{@category}/#{@name}/edit"
  end
end

get '/:category/:name' do
  require_signed_in_user

  @category = params[:category].to_sym
  @name = params[:name].to_sym

  contact_info = session[:contact_list][@category][@name]
  @phone = contact_info[:phone]
  @email = contact_info[:email]
  erb :contact
end
