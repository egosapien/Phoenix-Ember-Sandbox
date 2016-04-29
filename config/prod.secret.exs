use Mix.Config

# In this file, we keep production configuration that
# you likely want to automate and keep it away from
# your version control system.
config :peepchat, Peepchat.Endpoint,
  secret_key_base: "VmXDx0aoDjAG0erXnB9qdnB+d0VBQNYTbsaCKkTA/vE8UUgv+sc9g0Wch3ULF8WY"

# Configure your database
config :peepchat, Peepchat.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "peepchat_prod",
  pool_size: 20
