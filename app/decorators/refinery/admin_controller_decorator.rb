# app/decorators/refinery/admin_controller_decorator.rb

module RefineryAdminControllerAuthenticationDecorator
  protected

  def authenticate_refinery_user!
    authenticate_administrator!
  end
end

Refinery::AdminController.send :prepend, RefineryAdminControllerAuthenticationDecorator
