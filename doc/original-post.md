---
layout: post

title:  "Logging into RefineryCMS with an existing Devise user"
date:   2016-12-23 09:00:00 +1300
author: josh
---

For simple content management using Ruby on Rails, [RefineryCMS]() is a great option - it's an actively-maintained project with support for plugins (via Rails engines which lots of Rabid staff are already familiar with), and a reasonably easy to understand codebase. When we are called upon to add CMS features to an existing Rails application though, we usually already have some kind of authentication system in place. This blog post outlines how we configure Refinery to use our existing authentication system to authenticate and authorize CMS editors.

<!--break-->

If you are reading this blog post, you probably already have a Rails application ready to go to which you're wanting to add Refinery. If you're wanting to follow along with a simple example, these are the commands I have used to set up the example application:

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

There is also an [example reference application available](https://github.com/rabid/refinerycms-devise-authentication-blog-post-example).

If you haven't yet added RefineryCMS to your own application, the [RefineryCMS Guides can help you out](http://www.refinerycms.com/guides/with-an-existing-rails-app).

> NOTE: As of writing, RefineryCMS does not yet support Rails 5 due to some [issues](https://github.com/refinery/refinerycms/pull/3122). We made the difficult decision to stick with Rails 4, but will be upgrading as soon as possible.

With Refinery installed, you can start your Rails server (`bundle exec rails server`), and head to http://localhost:3000/refinery. You should see the Refinery dashboard - if so - great! We're done then ... except that we didn't have to log in to access that page! That means that any person could come along and start editing pages in your CMS - not good!

What we need to do is set up Refinery to check that a user is logged in. If you didn't already have a user account (for example, in our example app, we have "Administrators"), then a simple solution would be to add [refinerycms-authentication-devise](https://github.com/refinery/refinerycms-authentication-devise) to your `Gemfile`. This Refinery plugin adds the necessary security checks to Refinery to require a user be logged in with the correct role in order to access the particular resource. There are a couple of downsides to this approach though:

1. We already have a Devise user model we want to use. We don't really want Refinery to add a whole other type of user to our application.
2. The plugin adds a bunch of other stuff, not just authentication, including an authorization framework, and the ability to manage Refinery users and their roles from the Refinery dashboard. If you don't need roles for different users, or have your own authorization framework you want to use (we'll cover this soon!), or if you already have the ability to manage administrators elsewhere in your application, you probably don't want all of these features.

So, this gem is great if you are just trying to add authentication quickly, but it adds way more stuff than we need. We just want to Refinery to check that our existing user is already logged in, that's all!

To understand how to do this, we needed to jump into the code a bit to understand how RefineryCMS was authenticating a user. Since we already knew the refinerycms-authentication-devise gem did what we needed it to do, just with the wrong type of user, that was a good starting point. After a quick look through this plugin, we [noticed that the plugin code was overriding a method](https://github.com/refinery/refinerycms-authentication-devise/blob/1.0.4/app/decorators/controllers/refinery/admin_controller_decorator.rb) in a Refinery controller. Great - so the plugin has told us that it is overriding `Refinery::AdminController`'s `authenticate_refinery_user!` method, and we now know what method WE need to override.

There are lots of ways to replace or tweak how methods are implemented with Ruby - some better than others! Refinery has a particular approach they encourage to alter how Refinery will behave. When you ran `rails generate refinery:cms`, you may have noticed that an `app/decorators` directory was created. You can put modules in here that override Refinery files, and then include them in the particular class you are trying to alter.

Let's add a module to implement `authenticate_refinery_user!` - it's going to be very simple, because Devise already provides an `authenticate_[scope]!` method - in our example app, that's going to be `authenticate_administrator!`.

``` ruby
# app/decorators/refinery/admin_controller_decorator.rb

module RefineryAdminControllerAuthenticationDecorator
  protected

  def authenticate_refinery_user!
    authenticate_administrator!
  end
end

module Refinery
  module SiteBarHelper
    def display_site_bar?
      administrator_signed_in?
    end
  end
end

Refinery::AdminController.send :prepend, RefineryAdminControllerAuthenticationDecorator
```

If you restart your rails server to make sure these changes have been loaded, and try and go to http://localhost:3000/refinery again - success! You should be redirected to Devise's sign in page, and after signing in (if you are following the example app, try test@example.com, and "password"), will be redirected to Refinery's dashboard - now authenticated.

This is technically enough now, so if you just need to have your Devise user log in to Refinery, you're all done! We added some feature tests to verify that an administrator could go to Refinery, log in, and access the Refinery dashboard and declared the feature ready for sign off. There are a couple more things we can add though, so if you're interested, stick around.

----

#### Authorisation

Something that refinerycms-authentication-devise adds is a roles association with Refinery users and an authorization framework that restricts access to certain Refinery resources (pages, images, etc) to only those users who have that role.

If you are already using an authorization framework elsewhere in your application, or if you do need fine-grained permissions to access Refinery resources, we can add that pretty easily - we just need to take a look in [Refinery's admin base controller](https://github.com/refinery/refinerycms/blob/2c3b7c31314cc3fbcd425d7c461e14002bfda7fc/core/lib/refinery/admin/base_controller.rb#L64) to see that there is a method named `allow_controller?(controller_name)` where an authorized check is performed. If we extend our decorator to also override this method, we can replace the method with any implementation we want to. I'm not going to cover all the different ways you can authorize controller actions in this post, but here is an example of a decorator that performs authorization with [Pundit](https://github.com/elabs/pundit):

``` ruby
# app/decorators/refinery/admin_controller_decorator.rb

module RefineryAdminControllerAuthenticationDecorator
  include Pundit

  protected

  def pundit_user
    current_administrator
  end

  # ...

  def allow_controller?(controller_name)
    authorize controller_name.to_sym, params[:action]
  end
end

Refinery::AdminController.send :prepend, RefineryAdminControllerAuthenticationDecorator
```

Your Pundit policy could be implemented however you want - you might stick with a user having roles and controlling access that way, but it can be anything - you could only allow editing pages between 4-5pm on a Friday afternoon, or require users to have a special flag on their account. The point is that because you are using your own authorization framework, you have the ability to restrict access to different resourcess however you wish.

#### Logging out

If you are particularly eagle-eyed, you may have noticed that the [Refinery demo](https://stable-demo.refinerycms.com/refinery/pages) which uses refinerycms-authentication-devise has a "Log out" link that can be clicked, while our Refinery dashboard does not have any such link, even when we are logged in.

After a quick Github search in the RefineryCMS project, we found two partials, `_menu` and `_site_bar` which render this log out link:

``` ruby
<%= link_to Refinery::Core.refinery_logout_path, id:'logout', class: 'log-out' do %>
  <%= t('.log_out', site_bar_translate_locale_args) %>
  <%= content_tag(:i, nil, class: 'icon icon-log-out') %>
<% end if Refinery::Core.refinery_logout_path.present? %>
```

So, if `Refinery::Core.refinery_logout_path` is defined, a log out link will be rendered pointing at that URL. We can easily add that in config, as Refinery has already generated a config file for configuring `Refinery::Core`, in `config/initializers/refinery/core.rb`. Before we add this configuration variable, a reminder - this is an initialiser, which runs before your application routes have loaded - so you can't use URL helpers like `new_administrator_session_path` here - you'll need to use a string path that this kind of helper would normally return (behind the scenes, `link_to` actually uses [`url_for`](http://apidock.com/rails/ActionView/RoutingUrlFor/url_for), so you can also set it to a hash as long as that hash will resolve to a route). Here's the change we have added for our example app:

``` ruby
# encoding: utf-8
Refinery::Core.configure do |config|
  # ... rest of the config here ...

  config.refinery_logout_path = "/administrator/sign_out"
end
```

If you restart your Rails server and log back in to Refinery, you should see that log out link to sign out as an administrator - if you click it though, and it doesn't work, it might be because by default Devise does not allow access to the sign out link via a GET request - only DELETE. The link Refinery renders is going to be a GET request, because link elements always perform GET requests. This can be changed in `config/initializers/devise.rb` under the `sign_out_via` key - you can either just change it to `:get`, or allow `[:get, :delete]` to support both. If you aren't comfortable changing this, you will need to override both of these partials from Refinery so that you have full control over how the link is presented - there is a guide on [how to override views in the Refinery guides](http://www.refinerycms.com/guides/overriding-views). The disadvantage of replacing these partials with your own versions is that if a future version of Refinery changes how these partials are rendered, your partials may also need updating. The advantage is that you can put anything in the partials you wish - for example, you can easily add the current administrator's email or name next to the log out link.

----

RefineryCMS is pretty well put together, and we're lucky that these hook methods exist in the codebase, with a clear path to update how they work. Hopefully this blog post has helped you to plug your existing authentication system into your new RefineryCMS engine.
