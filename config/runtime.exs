import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/dakka start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :dakka, DakkaWeb.Endpoint, server: true
end

if System.get_env("DEMO_MODE") do
  config :dakka, demo_mode: true
end

if app_name = System.get_env("FLY_APP_NAME") do
  config :dakka, :dns_cluster_query, "#{app_name}.internal"
end

# Dynamically configure oauth for any env
config :dakka, :oauth,
  discord: [
    client_id: System.get_env("DISCORD_CLIENT_ID"),
    client_secret: System.get_env("DISCORD_CLIENT_SECRET"),
    redirect_uri: System.get_env("DISCORD_REDIRECT_URI")
  ]

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ssl = System.get_env("ECTO_SSL") in ~w(true 1)
  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []
  %URI{host: database_host} = URI.parse(database_url)

  config :dakka, Dakka.Repo,
    ssl: maybe_ssl,
    url: database_url,
    ssl_opts: [
      verify: :verify_peer,
      cacertfile: Path.join(:code.priv_dir(:dakka), "certs/team.pem"),
      server_name_indication: to_charlist(database_host)
    ],
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :dakka, DakkaWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base,
    check_origin: [
      "//*.dakka.live",
      "https://dakka.live",
      "https://dakka.fly.dev"
    ]

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :dakka, DakkaWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your endpoint, ensuring
  # no data is ever sent via http, always redirecting to https:
  #
  #     config :dakka, DakkaWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Also, you may need to configure the Swoosh API client of your choice if you
  # are not using SMTP. Here is an example of the configuration:
  #
  config :dakka, Dakka.Mailer,
    adapter: Swoosh.Adapters.Brevo,
    api_key: System.get_env("BREVO_API_KEY")

  # For this example you need include a HTTP client required by Swoosh API client.
  # Swoosh supports Hackney and Finch out of the box:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Hackney
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.

  # Sentry config
  config :sentry,
    environment_name: System.get_env("DEPLOY_ENV_NAME") || config_env()

  # Setup otel
  config :opentelemetry,
    resource: [
      service: [
        name: System.get_env("FLY_APP_NAME", "Dakka App"),
        namespace: "Dakka",
        instance: [
          id: System.get_env("FLY_ALLOC_ID")
        ]
        # ...
      ],
      host: [
        name: host
        # ...
      ],
      cloud: [
        provider: "fly_io",
        region: %{
          id: System.get_env("FLY_REGION")
        }
      ]
    ]

  config :opentelemetry_exporter,
    otlp_protocol: :http_protobuf,
    otlp_endpoint: "https://api.honeycomb.io:443",
    otlp_headers: [
      {"x-honeycomb-team", System.get_env("HONEYCOMB_API_KEY")},
      {"x-honeycomb-dataset", System.get_env("FLY_APP_NAME")}
    ]

  config :opentelemetry,
    span_processor: :batch,
    exporter: :otlp

  # Admins
  if admins = System.get_env("ADMIN_USERNAMES", "") do
    admin_usernames =
      admins
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.filter(&(&1 != ""))

    config :dakka, :admin_usernames, admin_usernames
  end
end
