defmodule Boson.Net do
  @moduledoc """
  Placeholder for BEAM-owned network orchestration.
  """

  use GenServer

  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    Logger.info("Boson.Net online")
    {:ok, %{status: :online, options: opts}}
  end
end
