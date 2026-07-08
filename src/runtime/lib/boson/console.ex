defmodule Boson.Console do
  @moduledoc """
  Placeholder for console ownership after Gluon has launched the runtime.
  """

  use GenServer

  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    Logger.info("Boson.Console online")
    {:ok, %{status: :online, options: opts}}
  end
end
