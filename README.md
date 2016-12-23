This Rails application is a companion to [this blog post on how to set up Refinery to use an existing Devise user](). In case of broken or expired links, you can find an unmaintained copy of the original blog post in the `doc/` folder.

This application has been set up with the following steps:

``` sh

# Use Rails 4.2
gem install rails -v "~> 4.2.7.1"
rails _4.2.7.1_ new refinerycms_authentication_example --skip-bundle

# Enter our application
cd refinerycms_authentication_example

# Install Devise and Refinery
echo "gem 'refinerycms', '~> 3.0.0'" >> Gemfile
echo "gem 'devise'" >> Gemfile

# Set up Devise, a Devise user and RefineryCMS
bundle exec rails g devise:install
sed -i '' 's/# config.secret_key/config.secret_key/' config/initializers/devise.rb
bundle exec rails g devise Administrator
bundle exec rails g refinery:cms --fresh-installation

# Add our own version of the routes, otherwise Refinery wipes out Devise's routes
echo "Rails.application.routes.draw do\n  devise_for :administrators\n  mount Refinery::Core::Engine, at: Refinery::Core.mounted_path\nend" > config/routes.rb

# Add a line to our seeds to create an administrator
echo "Administrator.create(email: 'test@example.com', password: 'password', password_confirmation: 'password')" >> db/seeds.rb

# Create, migrate, and seed the database.
bundle exec rake db:setup
```

The `fresh-setup` branch contains the repo at this point. The `master` branch contains the state of the repo after working through the steps outlined in the blog post.
