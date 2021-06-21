ENV["RACK_ENV"] = "test"

require 'bundler/setup'
require "fileutils"

require "minitest/autorun"
require "rack/test"


require_relative "../cms"

class CmsTest < Minitest::Test
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

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def session
    last_request.env["rack.session"]
  end

  def test_index
    create_document "about.md"
    create_document "changes.txt"

    get '/'

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
  end

  def test_get_file
    create_document "history.txt", "1993 - Yukihiro Matsumoto dreams up Ruby."

    get '/history.txt'

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "Yukihiro Matsumoto dreams up Ruby."
  end

  def test_document_not_found
    get '/unicorn.txt'

    assert_equal 302, last_response.status
    assert_equal "unicorn.txt does not exist.", session[:message]
  end

  def test_view_markdown_as_HTML
    create_document "about.md", "# Ruby is ..."

    get '/about.md'

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Ruby is ...</h1>"
  end

  def test_editing_content
    create_document "changes.txt"

    get '/changes.txt/edit'

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_updating_content
    post '/changes.txt', file_content: "new content"

    assert_equal 302, last_response.status
    assert_equal "changes.txt has been updated.", session[:message]

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end

  def test_view_new_document_form
    get '/new'

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_create_new_document
    post '/create', filename: "test.txt"

    assert_equal 302, last_response.status
    assert_equal "test.txt has been created.", session[:message]

    get '/'
    assert_includes last_response.body, "test.txt"
  end

  def test_create_new_document_without_filename
    post 'create', filename: ""

    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required."
  end

  def test_create_new_document_without_file_extension
    post 'create', filename: "test"

    assert_equal 422, last_response.status
    assert_includes last_response.body, ".txt or .md file extension is required."
  end

  def test_deleting_document
    create_document "test.txt"

    post '/test.txt/destroy'

    assert_equal 302, last_response.status
    assert_equal "test.txt has been deleted.", session[:message]

    get '/'
    refute_includes last_response.body, %q(href="/test.txt")
  end

  def test_signin_form
    get '/users/signin'

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_signin
    post 'users/signin', username: 'admin', password: 'secret'

    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:message]
    assert_equal "admin", session[:username]

    get last_response["Location"]
    refute_includes last_response.body, "Signed in as admin."
  end

  def test_signin_with_invalid_credentials
    post 'users/signin', username: 'admin', password: 'wrong'
    assert_equal 422, last_response.status
    assert_nil session[:username]
    assert_includes last_response.body, "Invalid credentials."
  end

  def test_signout
    get '/', {}, {"rack.session" => { username: "admin" } }
    assert_includes last_response.body, "Signed in as admin"

    post 'users/signout'
    assert_equal "You have been signed out", session[:message]

    get last_response["Location"]
    assert_nil session[:username]
    assert_includes last_response.body, "Sign In"
  end
end
