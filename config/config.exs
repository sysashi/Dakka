# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :dakka,
  ecto_repos: [Dakka.Repo]

# Configures the endpoint
config :dakka, DakkaWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: DakkaWeb.ErrorHTML, json: DakkaWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Dakka.PubSub,
  live_view: [signing_salt: "vQah1+0z"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :dakka, Dakka.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.19.5",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.3.3",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_handler, level: :debug

config :logger, :default_formatter,
  format: "$time $message[$level] $metadata\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Cldr config
config :ex_cldr,
  default_locale: "en",
  default_backend: Dakka.Cldr

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.

# Sentry config
config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  client: Dakka.Utils.SentryFinchHTTPClient,
  included_environments: :all,
  environment_name: config_env(),
  enable_source_code_context: true,
  root_source_code_paths: [File.cwd!()]

config :dakka, :logger, [
  {:handler, :sentry_handler, Sentry.LoggerHandler, %{config: %{}}}
]

config :opentelemetry,
       :sampler,
       {
         OpentelemetryHoneycombSampler,
         %{
           root: {Dakka.Utils.HoneycombSampler, %{}}
         }
       }

config :dakka, Oban,
  repo: Dakka.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 10]

config :dakka, :admin_usernames, []

config :dakka, :oauth,
  discord: [
    client_id: System.get_env("DISCORD_CLIENT_ID"),
    client_secret: System.get_env("DISCORD_CLIENT_SECRET"),
    redirect_uri: System.get_env("DISCORD_REDIRECT_URI")
  ]

import_config "#{config_env()}.exs"
