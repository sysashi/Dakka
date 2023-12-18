defmodule DakkaWeb.Router do
  use DakkaWeb, :router

  import DakkaWeb.UserAuth
  import DakkaWeb.Hooks.OtelAttrs, only: [otel_attrs: 2]

  alias DakkaWeb.Hooks

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {DakkaWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
    plug :otel_attrs
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", DakkaWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/oauth/callbacks/:provider", OauthCallbackController, :new
  end

  scope "/", DakkaWeb do
    pipe_through :browser

    get "/credits", PageController, :credits

    live_session :home_page,
      on_mount: [
        {DakkaWeb.UserAuth, :redirect_if_user_is_authenticated},
        Hooks.OtelAttrs,
        Hooks.Scope,
        Hooks.Nav,
        {Hooks.User, :app_settings},
        {Hooks.User, {:notifications, subscribe?: false}},
        Hooks.Announcements
      ] do
      live "/", MarketLive, :index
      live "/quick-buy/:listing_id", MarketLive, :quick_buy_dialog
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", DakkaWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:dakka, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).

    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  scope "/dashboard", DakkaWeb do
    import Phoenix.LiveDashboard.Router

    pipe_through [:browser, :require_authenticated_user, :require_admin_user]

    live_session :admin,
      on_mount: [
        {DakkaWeb.UserAuth, :ensure_authenticated},
        Hooks.Scope,
        Hooks.Nav,
        {Hooks.User, :notifications},
        Hooks.Announcements
      ] do
      live "/announcements", AnnouncementLive, :index
      live "/announcements/new", AnnouncementLive, :new
      live "/announcements/:id/edit", AnnouncementLive, :edit

      live "/announcements/:id", AnnouncementLive.Show, :show
      live "/announcements/:id/show/edit", AnnouncementLive.Show, :edit
    end

    live_dashboard "/",
      metrics: DakkaWeb.Telemetry,
      ecto_repos: [Dakka.Repo],
      ecto_psql_extras_options: [long_running_queries: [threshold: "200 milliseconds"]]
  end

  ## Authentication routes

  scope "/", DakkaWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [
        {DakkaWeb.UserAuth, :redirect_if_user_is_authenticated},
        Hooks.Scope,
        Hooks.Nav,
        {Hooks.User, :notifications},
        Hooks.Announcements
      ] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", DakkaWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [
        {DakkaWeb.UserAuth, :ensure_authenticated},
        Hooks.OtelAttrs,
        Hooks.Scope,
        Hooks.Nav,
        {Hooks.User, :app_settings},
        {Hooks.User, {:notifications, subscribe?: false}},
        Hooks.MarketPresence,
        Hooks.Announcements
      ] do
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email

      live "/add_item", Inventory.AddItemLive, :index

      live "/market", MarketLive, :index
      live "/market/offer/:listing_id", MarketLive, :new_offer
      live "/market/quick-buy/:listing_id", MarketLive, :quick_buy_dialog

      live "/inventory", InventoryLive, :index
      live "/inventory/list_item/:id", InventoryLive, :new_listing
      live "/inventory/edit_listing/:id", InventoryLive, :edit_listing

      live "/characters", CharactersLive, :index
      live "/characters/add", CharactersLive, :new_character
      live "/characters/edit/:id", CharactersLive, :edit_character

      live "/offers", OffersLive, :index
      live "/trade/:id", TradeLive, :index
    end
  end

  scope "/", DakkaWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [
        {DakkaWeb.UserAuth, :mount_current_user},
        Hooks.OtelAttrs,
        Hooks.Scope,
        Hooks.Nav,
        {Hooks.User, :notifications},
        Hooks.Announcements
      ] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end
end
