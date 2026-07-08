defmodule Boson.Application do
  @moduledoc """
  OTP application entrypoint for the BosonOS runtime.
  """

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("starting BosonOS runtime")
    Boson.Supervisor.start_link([])
  end
end
