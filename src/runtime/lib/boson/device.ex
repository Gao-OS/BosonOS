defmodule Boson.Device do
  @moduledoc """
  Placeholder for BEAM-owned device discovery and control.
  """

  use GenServer

  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    Logger.info("Boson.Device online")
    {:ok, %{status: :online, options: opts}}
  end
end
