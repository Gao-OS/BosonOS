defmodule Boson.Application do
  @moduledoc """
  OTP application entrypoint for the BosonOS runtime.
  """

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("starting BosonOS runtime")
    epoch = Boson.Boot.new_epoch()
    opts = [epoch: epoch, test_action: Application.get_env(:boson, :lifecycle_test_action)]

    case Boson.Supervisor.start_link(opts) do
      {:ok, pid} ->
        {:ok, pid, epoch}

      error ->
        Boson.Boot.delete_epoch(epoch)
        error
    end
  end

  @impl true
  def stop(epoch) do
    Boson.Boot.delete_epoch(epoch)
    :ok
  end
end
