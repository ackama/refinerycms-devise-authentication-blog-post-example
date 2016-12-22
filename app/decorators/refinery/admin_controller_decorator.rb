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
