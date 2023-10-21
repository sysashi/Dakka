defmodule DndahWeb.Router do
  use DndahWeb, :router

  import DndahWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {DndahWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", DndahWeb do
    pipe_through :browser

    # get "/", PageController, :home

    live_session :home_page,
      on_mount: [
        {DndahWeb.UserAuth, :redirect_if_user_is_authenticated},
        DndahWeb.Hooks.Scope,
        DndahWeb.Hooks.Nav
      ] do
      live "/", MarketLive, :index
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", DndahWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:dndah, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).

    # import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      # live_dashboard "/dashboard", metrics: DndahWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", DndahWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{DndahWeb.UserAuth, :redirect_if_user_is_authenticated}, DndahWeb.Hooks.Nav] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", DndahWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [
        {DndahWeb.UserAuth, :ensure_authenticated},
        DndahWeb.Hooks.Scope,
        DndahWeb.Hooks.Nav
      ] do
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email

      live "/entity_search", Game.EntitySearchLive, :index
      live "/add_item", Inventory.AddItemLive, :index
      live "/market", MarketLive, :index
      live "/market/offer/:listing_id", MarketLive, :new_offer
      live "/offers", OffersLive, :index
      live "/trade/:id", TradeLive, :index

      live "/inventory", InventoryLive, :index
      live "/inventory/list_item/:id", InventoryLive, :new_listing
      live "/inventory/edit_listing/:id", InventoryLive, :edit_listing
    end
  end

  scope "/", DndahWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{DndahWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end
end
