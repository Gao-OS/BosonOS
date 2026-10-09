defmodule Boson.SupervisorTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog
  alias Boson.Boot
  @moduletag :tmp_dir

  test "starts the initial BosonOS control-plane services" do
    pid = Process.whereis(Boson.Supervisor)
    assert is_pid(pid)

    child_ids =
      pid
      |> Supervisor.which_children()
      |> Enum.map(fn {id, _pid, _type, _modules} -> id end)
      |> Enum.sort_by(&inspect/1)

    assert child_ids == [
             Boson.Boot,
             Boson.Bus,
             Boson.Console,
             Boson.Device,
             Boson.Net,
             Boson.Update
           ]

    expected = Enum.sort_by(Boson.Supervisor.components(), &inspect/1)
    assert %{phase: :ready, missing_components: [], online_components: ^expected} = ready()

    for component <- Boson.Supervisor.components() do
      component_pid = Process.whereis(component)

      assert {:ready, ^component, ^component_pid} =
               GenServer.call(component_pid, :boson_readiness)
    end
  end

  test "Boot restarts independently and reconciles live components" do
    initial = ready()
    old = Process.whereis(Boson.Boot)
    components = Map.new(Boson.Supervisor.components(), &{&1, Process.whereis(&1)})

    log =
      capture_log(fn ->
        Process.exit(old, :kill)
        replacement = new_boot(old)
        refute replacement == old
        assert %{phase: :ready} = recovered = ready()
        assert recovered.ready_at_ms == initial.ready_at_ms
        assert Map.new(Boson.Supervisor.components(), &{&1, Process.whereis(&1)}) == components
      end)

    assert log =~ "Boson.Runtime recovered"
    refute log =~ "Boson.Runtime ready"
  end

  test "application startup error does not retain a new epoch" do
    epochs = epoch_keys()
    supervisor = Process.whereis(Boson.Supervisor)
    assert {:error, {:already_started, ^supervisor}} = Boson.Application.start(:normal, [])
    assert epoch_keys() == epochs
  end

  defp epoch_keys do
    :persistent_term.get()
    |> Enum.flat_map(fn
      {{Boot, _ref} = key, _value} -> [key]
      _entry -> []
    end)
    |> MapSet.new()
  end

  test "required-child startup failure never emits readiness and epoch is cleaned", %{
    tmp_dir: root
  } do
    application_epoch = :sys.get_state(Boson.Boot).epoch
    assert :ok = Application.stop(:boson)
    assert :persistent_term.get(application_epoch, :missing) == :missing
    on_exit(fn -> {:ok, _} = Application.ensure_all_started(:boson) end)
    epoch = Boot.new_epoch()
    on_exit(fn -> Boot.delete_epoch(epoch) end)
    test_pid = self()

    blocker =
      spawn(fn ->
        Process.register(self(), Boson.Update)
        send(test_pid, :registered)

        receive do
          :stop -> :ok
        end
      end)

    assert_receive :registered
    on_exit(fn -> if Process.alive?(blocker), do: Process.exit(blocker, :kill) end)
    previous = Process.flag(:trap_exit, true)

    try do
      log =
        capture_log(fn ->
          assert {:error, {:shutdown, {:failed_to_start_child, Boson.Update, _reason}}} =
                   Boson.Supervisor.start_link(
                     name: nil,
                     epoch: epoch,
                     action_path: Path.join(root, "action"),
                     shutdown: fn _ -> :ok end
                   )
        end)

      refute log =~ "Boson.Runtime ready"
    after
      receive do
        {:EXIT, _pid, _reason} -> :ok
      after
        0 -> :ok
      end

      Process.flag(:trap_exit, previous)
      Process.exit(blocker, :kill)
      monitor = Process.monitor(blocker)
      assert_receive {:DOWN, ^monitor, :process, ^blocker, _}
      {:ok, _} = Application.ensure_all_started(:boson)
    end
  end

  defp ready(attempts \\ 100)
  defp ready(0), do: Boot.status()

  defp ready(attempts) do
    case Boot.status() do
      %{phase: :ready} = status ->
        status

      _ ->
        Process.sleep(10)
        ready(attempts - 1)
    end
  end

  defp new_boot(old, attempts \\ 100)
  defp new_boot(_old, 0), do: Process.whereis(Boson.Boot)

  defp new_boot(old, attempts) do
    case Process.whereis(Boson.Boot) do
      pid when is_pid(pid) and pid != old ->
        pid

      _ ->
        Process.sleep(10)
        new_boot(old, attempts - 1)
    end
  end
end
