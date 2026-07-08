defmodule Boson.Update do
  @moduledoc """
  Placeholder for image/update orchestration owned by the BEAM runtime.
  """

  use GenServer

  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    Logger.info("Boson.Update online")
    {:ok, %{status: :online, options: opts}}
  end
end
