defmodule Boson.Supervisor do
  @moduledoc """
  Top-level supervisor for the BosonOS BEAM control plane.
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl true
  def init(_opts) do
    children = [
      Boson.Boot,
      Boson.Bus,
      Boson.Device,
      Boson.Net,
      Boson.Console,
      Boson.Update
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
