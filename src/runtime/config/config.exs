import Config

lifecycle_test_action =
  case System.get_env("BOSON_LIFECYCLE_TEST_ACTION") do
    nil -> nil
    "reboot" -> :reboot
    "poweroff" -> :poweroff
  end

config :boson, lifecycle_test_action: lifecycle_test_action

config :logger, :default_formatter, format: "$time $metadata[$level] $message\n"
