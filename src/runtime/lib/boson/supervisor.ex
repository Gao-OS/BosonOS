defmodule Boson.Supervisor do
  @moduledoc """
  Top-level supervisor for the BosonOS BEAM control plane.
  """

  use Supervisor

  @components [Boson.Bus, Boson.Device, Boson.Net, Boson.Console, Boson.Update]

  def components, do: @components

  def start_link(opts) do
    {name, init_opts} = Keyword.pop(opts, :name, __MODULE__)

    case name do
      nil -> Supervisor.start_link(__MODULE__, init_opts)
      registered -> Supervisor.start_link(__MODULE__, init_opts, name: registered)
    end
  end

  @impl true
  def init(opts) do
    boot_opts =
      [
        epoch: Keyword.fetch!(opts, :epoch),
        required_components: @components,
        test_action: Keyword.get(opts, :test_action)
      ] ++ Keyword.take(opts, [:action_path, :shutdown])

    Supervisor.init([{Boson.Boot, boot_opts} | @components], strategy: :one_for_one)
  end
end
