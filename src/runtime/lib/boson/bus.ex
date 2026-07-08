defmodule Boson.Bus do
  @moduledoc """
  Placeholder for the local BosonOS control/event bus.
  """

  use GenServer

  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    Logger.info("Boson.Bus online")
    {:ok, %{status: :online, options: opts}}
  end
end
