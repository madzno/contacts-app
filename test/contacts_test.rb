ENV["RACK_ENV"] = "test"

require "fileutils"

require "minitest/autorun"
require "rack/test"

require_relative "../contacts"

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    { "rack.session" => { username: "admin" } }
  end

  def test_home_signed_out
    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h3>Welcome to MyContacts"
    assert_includes last_response.body, %q(<a href="/signin")
    refute_includes last_response.body, %q(<button type="submit")
  end

  def test_home_signed_in
    get "/", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_view_signin_page
    get "/signin"

    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(<form action="/signin")
    assert_includes last_response.body, %q(<input name = "username")
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_signin
    post "/signin", username: "admin", password: "adminsecret"

    assert_equal 302, last_response.status
    assert_equal "Welcome admin!", session[:message]
    assert_equal "admin", session[:username]

    get last_response["Location"]
    assert_includes last_response.body, "Signed in as admin"
  end

  def test_signout
    post "signout"

    assert_equal 302, last_response.status
    assert_nil session[:username]
    assert_equal "You have been signed out.", session[:message]

    get last_response["Location"]
    assert_includes last_response.body, "Sign In"
  end

  def test_view_index
    get "/index", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<h3>Family"
    assert_includes last_response.body, %q(<a href="/friends/jill">Jill</a>)
    assert_includes last_response.body, %q(<a href="/contact/new">Add New)
  end

  def test_view_index_signed_out
    get "/index"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_view_individual_contact
    get "/work/john", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<p>Phone: 484-383-9028</p>"
    assert_includes last_response.body, "<p>Email: john@gmail.com</p>"
  end

  def test_view_individual_contact_signedout
    get "/friends/jill"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end
end
