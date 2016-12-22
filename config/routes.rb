Rails.application.routes.draw do
  devise_for :administrators
  mount Refinery::Core::Engine, at: Refinery::Core.mounted_path
end
