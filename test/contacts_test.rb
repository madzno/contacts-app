ENV['RACK_ENV'] = 'test'

require 'fileutils'

require 'minitest/autorun'
require 'rack/test'

require_relative '../contacts'

class ContactsTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def session
    last_request.env['rack.session']
  end

  def admin_session
    { 'rack.session' => {
                          username: 'admin',
                          contact_list: {:friends => { jill: { phone: '772-889-9005', email: 'jill@hotmail.com'}},
                                         :work => { john: { phone: '484-383-9028', email: 'john@gmail.com'} },
                                         :family => {} }
                        } }
  end

  def test_home_signed_out
    get '/'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<h3>Welcome to MyContacts'
    assert_includes last_response.body, %q(<a href="/signin")
    refute_includes last_response.body, %q(<button type="submit")
  end

  def test_home_signed_in
    get '/', {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_view_signin_page
    get '/signin'

    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(<form action="/signin")
    assert_includes last_response.body, %q(<input name="username")
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_signin
    post '/signin', username: 'admin', password: 'adminsecret'

    assert_equal 302, last_response.status
    assert_equal 'Welcome admin!', session[:message]
    assert_equal 'admin', session[:username]

    get last_response['Location']
    assert_includes last_response.body, 'Signed in as admin'
  end

  def test_signout
    post 'signout'

    assert_equal 302, last_response.status
    assert_nil session[:username]
    assert_equal 'You have been signed out.', session[:message]

    get last_response['Location']
    assert_includes last_response.body, 'Sign In'
  end

  def test_view_index
    get '/index', {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, '<h3>Family'
    assert_includes last_response.body, %q(<a href="/friends/jill">Jill</a>)
    assert_includes last_response.body, %q(<a href="/contact/new">Add New)
  end

  def test_view_index_signed_out
    get '/index'

    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]
  end

  def test_view_individual_contact
    get '/work/john', {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, '<p>Phone: 484-383-9028</p>'
    assert_includes last_response.body, '<p>Email: john@gmail.com</p>'
  end

  def test_view_individual_contact_signedout
    get '/friends/jill'

    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]
  end

  def test_view_new_contact_form
    get '/contact/new', {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(<form action="/contact/new" method="post">)
    assert_includes last_response.body, %q(<input name="name")
    assert_includes last_response.body, %q(<input name="phone")
    assert_includes last_response.body, %q(<select id="category")
    assert_includes last_response.body, %q(<input name="email")
  end

  def test_view_new_contact_form_signedout
    get '/contact/new'

    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]
  end

  def test_add_new_contact
    post '/contact/new', { name: 'maddy', category: 'friends', phone: '444-678-9012', email: 'maddy@gmali.com'}, admin_session

    assert_equal 302, last_response.status

    get last_response['Location']
    assert_equal 200, last_response.status
    assert_includes session[:contact_list][:friends], :maddy
    assert_includes last_response.body, %q(<a href="/friends/maddy">Maddy</a>)
  end

  def test_add_new_contact_signedout
    get '/contact/new'

    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]
  end

  def test_add_new_contact_invalid_name_character_count
    post '/contact/new', { name: '', category: 'friends', phone: '555-666-777',
                           email: 'maddy@gmail.com'}, admin_session

    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Contact name must be between 1 and 100 characters'
  end

  def test_add_new_contact_invalid_name_not_unique
    post '/contact/new', { name: 'jill', category: 'friends', phone: '777-888-9900',
                           email: 'jill@hotmail.com' }, admin_session

    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Contact name must be unique.'
  end

  def test_add_new_contact_invalid_phone_number
    post '/contact/new', { name: 'hailey', category: 'family', phone: '09-88-77',
                           email: 'hailz@hotmail,com'}, admin_session

    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Please enter a valid 10 digit phone number in the format: XXX-XXX-XXXX'
  end

  def test_add_new_contact_invalid_email
    post '/contact/new', { name: 'thomas', category: 'work', phone: '999-020-3455',
                           email: 'thomasgmail' }, admin_session

    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Please enter a valid email address.'
  end

  def test_delete_contact_signedout
    post '/index/friends/jill/delete'

    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]
  end

  def test_delete_contact
    post '/index/friends/jill/delete', {}, admin_session

    assert_equal 302, last_response.status
    assert_nil session[:contact_list][:friends][:jill]
    assert_equal session[:message], 'Contact information for Jill deleted.'

    get last_response['Location']
    refute_includes last_response.body, %q(<a href="/friends/jill"> Jill </a>)
  end

  def test_view_edit_contact_page
    get '/friends/jill/edit', {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(<input name="phone")
    assert_includes last_response.body, %q(<input name="email")
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_view_edit_contact_page_signedout
    get '/friends/jill/edit'

    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]
  end

  def test_edit_phone
    post '/friends/jill/edit', { phone: "914-889-0090" }, admin_session

    assert_equal 302, last_response.status
    assert_equal '914-889-0090', session[:contact_list][:friends][:jill][:phone]
    assert_equal "Jill's phone updated.", session[:message]
  end

  def test_edit_email
    post '/work/john/edit', { email: 'john@hotmail.com' }, admin_session

    assert_equal 302, last_response.status
    assert_equal 'john@hotmail.com', session[:contact_list][:work][:john][:email]
    assert_equal "John's email updated.", session[:message]
  end

  def test_edit_contact_signedout
    post '/work/john/edit'

    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]
  end

  def test_edit_phone_invalid
    post '/friends/jill/edit', { phone: "914-889-009" }, admin_session

    assert_equal 422, last_response.status
    refute_equal '914-889-009', session[:contact_list][:friends][:jill][:phone]
    assert_includes last_response.body, 'Please enter a valid 10 digit phone number in the format: XXX-XXX-XXXX'
  end

  def test_edit_email_invalid
    post '/work/john/edit', { email: 'jhotmail' }, admin_session

    assert_equal 422, last_response.status
    refute_equal 'jhotmail', session[:contact_list][:work][:john][:email]
    assert_includes last_response.body, 'Please enter a valid email address.'
  end
end
