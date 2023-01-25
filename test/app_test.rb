ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require 'minitest/reporters'
Minitest::Reporters.use!
require 'fileutils'

require_relative "../app.rb"

def create_document(name, content = "")
  File.open(File.join(data_path, name), "w") do |file|
    file.write(content)
  end
end

def admin_session
  { "rack.session" => { username: "admin", login_status: true } }
end

def session
  last_request.env["rack.session"]
end

class AppTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def test_index
    create_document "about.md"
    create_document "changes.txt"

    get "/", {}, admin_session

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
  end

  def test_history
    create_document('history.txt', 'Last week I rode on the Delta SkyClub.')

    get "/history.txt", {}, admin_session
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "SkyClub"
  end

  def test_document_not_found
    get "/notafile.ext", {}, admin_session

    assert_equal 302, last_response.status # Assert that the user was redirected
    assert_equal "notafile.ext does not exist.", session[:error]
  end

  def test_markdown
    create_document('markdown_test.md','# Look, we all love *pumpkins*.')

    get "/markdown_test.md", {}, admin_session

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<em>pumpkins</em>"
  end

  def test_editing_document
    get "/changes.txt/edit", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_updating_document
    post "/changes.txt/save", { contents: "new content" }, admin_session

    assert_equal 302, last_response.status
    assert_equal "changes.txt has been updated.", session[:success]

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end

  def test_view_new_document_form
    get "/new", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_create_new_document
    post "/new", { file_name: "test.txt" }, admin_session
    assert_equal 302, last_response.status
    assert_equal "test.txt has been created.", session[:success]

    get "/"
    assert_includes last_response.body, "test.txt"
  end

  def test_create_new_document_without_filename
    post "/new", { filename: "" }, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required"
  end

  def test_create_and_delete_document
    create_document('testerfile.txt')

    get "/", {}, admin_session
    assert_includes last_response.body, "testerfile.txt"

    post "/testerfile.txt/delete"
    assert_equal 302, last_response.status
    assert_equal "testerfile.txt was deleted.", session[:success]

    get "/"
    refute_includes last_response.body, "/testerfile.txt"
  end

  def test_logged_out
    get "/"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Username"
  end

  def test_sign_in
    post "/signin", username: "admin", pw: "secret"
    assert_equal 302, last_response.status
    assert_equal session[:success], "Welcome!"
    assert_equal session[:username], "admin"

    get last_response["Location"]
    assert_includes last_response.body, "Signed in as admin"
  end

  def test_bad_credentials
    post "/signin", username: "admin", pw: "sss"
    assert_equal 422, last_response.status
    assert_nil session[:username]
    assert_includes last_response.body, "Invalid credentials"
  end

  def test_signout
    get "/", {}, admin_session
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Signed in as admin"

    post "/signout"
    assert_equal "You have been signed out.", session[:success]
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_nil session[:username]
    assert_includes last_response.body, "Sign In"
  end

  def test_logged_out_edit
    create_document('testfile.txt')

    get "/testfile.txt/edit"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]
  end

  def test_logged_out_save
    create_document('testfile.txt')

    post "/testfile.txt/save", contents: "This is a test"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]
  end

  def test_logged_out_new
    get "/new"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]
  end

  def test_logged_out_new_save
    post "/new", file_name: "testerfile.txt"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]
  end

  def test_logged_out_delete
    create_document("testerfile.txt")

    post "/testerfile.txt/delete"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]
  end
end
