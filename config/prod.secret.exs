use Mix.Config

# In this file, we keep production configuration that
# you likely want to automate and keep it away from
# your version control system.
config :peepchat, Peepchat.Endpoint,
  secret_key_base: "s6cf+dEc/uwnCjrv2WGfRfaGtXOedckUDkKmR17DxSCYFhe69bQ3Gz67DwB68pdx"

# Configure your database
config :peepchat, Peepchat.Repo,
  adapter: Ecto.Adapters.MySQL,
  username: "root",
  password: "",
  database: "peepchat_prod",
  pool_size: 20
