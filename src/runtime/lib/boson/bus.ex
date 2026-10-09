defmodule Boson.Bus do
  @moduledoc """
  Placeholder for the local BosonOS control/event bus.
  """

  use GenServer

  require Logger

  def start_link(opts) do
    {name, init_opts} = Keyword.pop(opts, :name, __MODULE__)

    case name do
      nil -> GenServer.start_link(__MODULE__, init_opts)
      registered -> GenServer.start_link(__MODULE__, init_opts, name: registered)
    end
  end

  @impl true
  def init(opts) do
    Logger.info("Boson.Bus online")
    {:ok, %{status: :online, options: opts}, {:continue, :report_ready}}
  end

  @impl true
  def handle_continue(:report_ready, state) do
    :ok = Boson.Boot.component_ready(__MODULE__, self())
    {:noreply, state}
  end

  @impl true
  def handle_call(:boson_readiness, _from, state) do
    {:reply, {:ready, __MODULE__, self()}, state}
  end
end
