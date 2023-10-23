import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :dakka, Dakka.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "dakka_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :dakka, DakkaWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "LHOt/voWjqTHk0lClCEhdy4oxh0jpDyVqAiTV7MqExaoGtUXPTof0HTePkWiyNtT",
  server: false

# In test we don't send emails.
config :dakka, Dakka.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, :default_handler, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Prevent Oban from running jobs and plugins during test runs
config :dakka, Oban, testing: :inline
