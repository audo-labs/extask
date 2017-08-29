use Mix.Config

config :extask, Extask,
  retry_timeout: 30000

import_config "#{Mix.env}.exs"
