defmodule Boson.Boot do
  @moduledoc """
  Coordinates runtime boot milestones after Gluon launches the OTP release.
  """

  use GenServer

  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    Logger.info("Boson.Boot online")
    {:ok, %{status: :online, options: opts}}
  end
end
