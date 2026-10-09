defmodule Boson.BootTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog
  alias Boson.{Boot, SystemAction}
  @moduletag :tmp_dir

  defmodule TestComponent do
    use GenServer

    def start_link(opts),
      do: GenServer.start_link(__MODULE__, opts, name: Keyword.fetch!(opts, :name))

    def init(opts) do
      state = Map.new(opts)

      if Map.get(state, :report, true),
        do: {:ok, state, {:continue, :report_ready}},
        else: {:ok, state}
    end

    def handle_continue(:report_ready, state) do
      :ok = Boot.component_ready(state.name, self(), state.boot)
      {:noreply, state}
    end

    def handle_call(:boson_readiness, _from, state) do
      if Map.has_key?(state, :test_pid), do: send(state.test_pid, {:probe_received, self()})

      if Map.get(state, :report_in_probe, false) do
        :ok = Boot.component_ready(state.name, self(), state.boot)
      end

      if Map.get(state, :pause_probe, false) do
        receive do
          :release_probe -> :ok
        end
      end

      {:reply, Map.get(state, :readiness_reply, {:ready, state.name, self()}),
       Map.delete(state, :pause_probe)}
    end

    def handle_call(:report_ready, _from, state),
      do: {:reply, Boot.component_ready(state.name, self(), state.boot), state}
  end

  defmodule SlowComponent do
    use GenServer

    def start_link(opts),
      do: GenServer.start_link(__MODULE__, opts, name: Keyword.fetch!(opts, :name))

    def init(opts) do
      name = Keyword.fetch!(opts, :name)
      send(Keyword.fetch!(opts, :test_pid), {:inside_init, name, self()})

      receive do
        {:finish_init, boot} -> {:ok, %{name: name, boot: boot}, {:continue, :report_ready}}
      end
    end

    def handle_continue(:report_ready, state) do
      :ok = Boot.component_ready(state.name, self(), state.boot)
      {:noreply, state}
    end

    def handle_call(:boson_readiness, _from, state),
      do: {:reply, {:ready, state.name, self()}, state}
  end

  setup %{tmp_dir: root} do
    epoch = Boot.new_epoch(fn -> 1_000 end)
    on_exit(fn -> Boot.delete_epoch(epoch) end)
    %{epoch: epoch, path: Path.join(root, "boson/action")}
  end

  test "stable initial status waits for the complete required set", context do
    boot = start_boot(context, required_components: [:net, :bus])

    assert Boot.status(boot) == %{
             phase: :starting,
             started_at_ms: 1_000,
             ready_at_ms: nil,
             online_components: [],
             missing_components: [:bus, :net],
             last_action: nil
           }

    start_component(:bus, boot)

    assert %{phase: :starting, online_components: [:bus]} =
             eventually(boot, &(&1.online_components == [:bus]))

    start_component(:net, boot)

    assert %{phase: :ready, missing_components: [], ready_at_ms: timestamp} =
             eventually(boot, &(&1.phase == :ready))

    assert is_integer(timestamp)
  end

  test "logs first readiness exactly once and duplicate reports are idempotent", context do
    boot = start_boot(context)

    log =
      capture_log(fn ->
        component = start_component(:bus, boot)
        assert %{phase: :ready} = eventually(boot, &(&1.phase == :ready))
        assert :ok = GenServer.call(component, :report_ready)
        assert :ok = GenServer.call(component, :report_ready)
      end)

    assert length(Regex.scan(~r/Boson.Runtime ready/, log)) == 1
    refute log =~ "Boson.Runtime recovered"
  end

  test "loss demotes readiness and recovery preserves timestamps", context do
    boot = start_boot(context)
    first = start_component(:bus, boot)
    initial = eventually(boot, &(&1.phase == :ready))

    log =
      capture_log(fn ->
        GenServer.stop(first)

        assert %{phase: :starting, missing_components: [:bus]} =
                 eventually(boot, &(&1.phase == :starting))

        start_component(:bus, boot)
        recovered = eventually(boot, &(&1.phase == :ready))
        assert recovered.ready_at_ms == initial.ready_at_ms
      end)

    assert log =~ "Boson.Runtime unavailable component=:bus reason=:normal"
    assert log =~ "Boson.Runtime recovered"
    refute log =~ "Boson.Runtime ready"
  end

  test "rejects unexpected and forged identities", context do
    boot = start_boot(context)
    assert {:error, :unexpected_component} = Boot.component_ready(:device, self(), boot)
    assert {:error, :identity_mismatch} = Boot.component_ready(:bus, self(), boot)
    component = start_component(:bus, boot)
    assert %{phase: :ready} = eventually(boot, &(&1.phase == :ready))
    assert {:error, :identity_mismatch} = Boot.component_ready(:bus, component, boot)
  end

  test "replacement readiness precedes old DOWN and ignores stale monitor messages", context do
    boot = start_boot(context)
    old = start_component(:bus, boot)
    assert %{phase: :ready} = eventually(boot, &(&1.phase == :ready))
    old_ref = :sys.get_state(boot).components.bus.ref
    Process.unregister(:bus)
    replacement = start_component(:bus, boot)
    assert {:ready, :bus, ^replacement} = GenServer.call(replacement, :boson_readiness)
    GenServer.stop(old)
    send(boot, {:DOWN, old_ref, :process, old, :normal})
    send(boot, {:DOWN, make_ref(), :process, replacement, :kill})
    assert %{phase: :ready, online_components: [:bus]} = Boot.status(boot)
  end

  test "five registered paused initializations never block reconciliation", context do
    test_pid = self()
    names = [:bus, :console, :device, :net, :update]

    components =
      Map.new(names, fn name ->
        spawn(fn ->
          result = SlowComponent.start_link(name: name, test_pid: test_pid)
          send(test_pid, {:slow_started, name, result})
        end)

        assert_receive {:inside_init, ^name, component}, 1_000
        assert Process.whereis(name) == component
        on_exit(fn -> if Process.alive?(component), do: Process.exit(component, :kill) end)
        {name, component}
      end)

    boot = start_boot(context, required_components: names)
    task = Task.async(fn -> Boot.status(boot) end)
    assert %{phase: :starting, missing_components: ^names} = Task.await(task, 500)
    assert map_size(:sys.get_state(boot).reconciliation_probes) == 5
    Enum.each(components, fn {_name, component} -> send(component, {:finish_init, boot}) end)

    Enum.each(components, fn {name, component} ->
      assert_receive {:slow_started, ^name, {:ok, ^component}}, 1_000
    end)

    assert %{phase: :ready} = eventually(boot, &(&1.phase == :ready))
  end

  test "ignores forged reconciliation results", context do
    boot = start_boot(context)
    component = start_component(:bus, boot, report: false)
    send(boot, {:reconcile_result, make_ref(), :bus, component, {:ready, :bus, component}})
    assert %{phase: :starting, online_components: []} = Boot.status(boot)
    assert :ok = GenServer.call(component, :report_ready)
    assert %{phase: :ready} = Boot.status(boot)
  end

  test "reconciliation rejects a mismatched private response", context do
    component =
      start_component(:bus, nil,
        report: false,
        readiness_reply: {:ready, :net, self()},
        test_pid: self()
      )

    boot = start_boot(context)
    assert_receive {:probe_received, ^component}, 1_000
    eventually_probes_finished(boot)
    assert %{phase: :starting, missing_components: [:bus]} = Boot.status(boot)
  end

  test "reconciliation times out without blocking or registering a nonresponsive component",
       context do
    component = start_component(:bus, nil, report: false, pause_probe: true, test_pid: self())
    boot = start_boot(context)
    assert_receive {:probe_received, ^component}, 1_000
    assert %{phase: :starting, missing_components: [:bus]} = Boot.status(boot)
    eventually_probes_finished(boot)
    assert %{phase: :starting, missing_components: [:bus]} = Boot.status(boot)
    send(component, :release_probe)
    assert {:ready, :bus, ^component} = GenServer.call(component, :boson_readiness)
    assert %{phase: :starting} = Boot.status(boot)
  end

  test "reconciliation catches a candidate exit and remains available", context do
    component = start_component(:bus, nil, report: false, pause_probe: true, test_pid: self())
    boot = start_boot(context)
    assert_receive {:probe_received, ^component}, 1_000
    Process.exit(component, :kill)
    eventually_probes_finished(boot)
    assert %{phase: :starting, missing_components: [:bus]} = Boot.status(boot)
  end

  test "a valid in-flight probe is ignored after stopping", context do
    component =
      start_component(:bus, :lifecycle_test_boot,
        report: false,
        report_in_probe: true,
        pause_probe: true,
        test_pid: self()
      )

    boot = start_boot(context, name: :lifecycle_test_boot)
    assert_receive {:probe_received, ^component}, 1_000
    assert %{phase: :ready} = eventually(boot, &(&1.phase == :ready))
    assert :ok = Boot.request_action(:poweroff, boot)
    assert_receive {:shutdown, 0}, 1_000
    send(component, :release_probe)
    eventually_probes_finished(boot)
    assert %{phase: :stopping, last_action: :poweroff} = Boot.status(boot)
  end

  test "Boot restart reconciles initialized components with recovered-only log", context do
    first = start_boot(context)
    start_component(:bus, first)
    ready = eventually(first, &(&1.phase == :ready))
    :ok = stop_supervised(Boot)

    log =
      capture_log(fn ->
        second = start_boot(context)
        recovered = eventually(second, &(&1.phase == :ready))
        assert recovered.ready_at_ms == ready.ready_at_ms
      end)

    refute log =~ "Boson.Runtime ready"
    assert log =~ "Boson.Runtime recovered"
  end

  for action <- [:reboot, :poweroff] do
    test "persists #{action} before one-shot clean shutdown", context do
      boot = start_boot(context)
      start_component(:bus, boot)
      assert %{phase: :ready} = eventually(boot, &(&1.phase == :ready))

      log =
        capture_log(fn ->
          assert :ok = Boot.request_action(unquote(action), boot)
          assert_receive {:shutdown, 0}, 1_000
        end)

      assert log =~ "Boson.Runtime stopping action=#{unquote(action)}"
      assert {:ok, unquote(action)} = SystemAction.read(context.path)
      assert %{phase: :stopping, last_action: unquote(action)} = Boot.status(boot)
      assert {:error, :already_stopping} = Boot.request_action(:reboot, boot)
      assert {:error, :unsupported_action} = Boot.request_action(:halt, boot)
      refute_receive {:shutdown, _}, 150
    end
  end

  test "validates action before phase and rejects pre-ready requests", context do
    boot = start_boot(context)
    assert {:error, :unsupported_action} = Boot.request_action(:halt, boot)
    assert {:error, :not_ready} = Boot.request_action(:poweroff, boot)
    refute File.exists?(context.path)
    refute_receive {:shutdown, _}, 150
  end

  test "persistence failure leaves readiness intact without shutdown", context do
    boot = start_boot(context)
    start_component(:bus, boot)
    assert %{phase: :ready} = eventually(boot, &(&1.phase == :ready))
    File.write!(Path.dirname(context.path), "not a directory")
    assert {:error, :eexist} = Boot.request_action(:reboot, boot)
    assert %{phase: :ready, last_action: nil} = Boot.status(boot)
    refute_receive {:shutdown, _}, 150
  end

  for action <- [:reboot, :poweroff] do
    test "resumes pending #{action} without readiness", context do
      assert :ok = SystemAction.write(unquote(action), context.path)

      log =
        capture_log(fn ->
          boot = start_boot(context)
          assert %{phase: :stopping, last_action: unquote(action)} = Boot.status(boot)
          assert_receive {:shutdown, 0}, 1_000
        end)

      refute log =~ "Boson.Runtime ready"
    end
  end

  test "malformed and unreadable pending files fail closed", context do
    for kind <- [:malformed, :unreadable] do
      path = context.path <> Atom.to_string(kind)
      File.mkdir_p!(Path.dirname(path))

      case kind do
        :malformed -> File.write!(path, "reboot now\n")
        :unreadable -> File.mkdir!(path)
      end

      boot = start_boot(context, action_path: path)
      assert %{phase: :stopping, last_action: nil} = Boot.status(boot)
      assert_receive {:shutdown, 1}, 1_000
      :ok = stop_supervised(Boot)
    end
  end

  test "private test action runs once on first epoch readiness", context do
    first = start_boot(context, test_action: :poweroff)
    component = start_component(:bus, first)
    assert %{phase: :ready} = eventually(first, &(&1.phase == :ready))
    assert :ok = GenServer.call(component, :report_ready)
    assert_receive {:shutdown, 0}, 1_000
    assert {:ok, :poweroff} = SystemAction.read(context.path)
    refute_receive {:shutdown, _}, 150
    :ok = stop_supervised(Boot)
    File.rm!(context.path)
    second = start_boot(context, test_action: :poweroff)
    assert %{phase: :ready} = eventually(second, &(&1.phase == :ready))
    refute_receive {:shutdown, _}, 200
    refute File.exists?(context.path)
  end

  test "private action uses the same unsupported-action validation", context do
    invalid = start_boot(context, test_action: :halt)
    start_component(:bus, invalid)
    assert %{phase: :ready} = eventually(invalid, &(&1.phase == :ready))
    refute_receive {:shutdown, _}, 200
    assert %{phase: :ready, last_action: nil} = Boot.status(invalid)
    refute File.exists?(context.path)
  end

  test "private action persistence failure leaves runtime ready", context do
    boot = start_boot(context, test_action: :poweroff)
    File.write!(Path.dirname(context.path), "not a directory")
    start_component(:bus, boot)
    assert %{phase: :ready} = eventually(boot, &(&1.phase == :ready))
    refute_receive {:shutdown, _}, 200
    assert %{phase: :ready, last_action: nil} = Boot.status(boot)
  end

  test "late reports, probes and loss preserve stopping action", context do
    boot = start_boot(context)
    first = start_component(:bus, boot)
    assert %{phase: :ready} = eventually(boot, &(&1.phase == :ready))
    assert :ok = Boot.request_action(:reboot, boot)
    assert_receive {:shutdown, 0}, 1_000
    GenServer.stop(first)

    assert %{phase: :stopping, missing_components: [:bus], last_action: :reboot} =
             eventually(boot, &(&1.missing_components == [:bus]))

    replacement = start_component(:bus, boot)
    assert {:ready, :bus, ^replacement} = GenServer.call(replacement, :boson_readiness)
    send(boot, {:reconcile_result, make_ref(), :bus, replacement, {:ready, :bus, replacement}})
    assert %{phase: :stopping, last_action: :reboot} = Boot.status(boot)
    refute_receive {:shutdown, _}, 150
  end

  defp start_boot(context, opts \\ []) do
    test_pid = self()

    defaults = [
      name: nil,
      epoch: context.epoch,
      required_components: [:bus],
      action_path: context.path,
      shutdown: fn code -> send(test_pid, {:shutdown, code}) end
    ]

    start_supervised!({Boot, Keyword.merge(defaults, opts)})
  end

  defp start_component(name, boot, opts \\ []) do
    spec = %{
      id: {name, make_ref()},
      start: {TestComponent, :start_link, [Keyword.merge([name: name, boot: boot], opts)]},
      restart: :temporary
    }

    start_supervised!(spec)
  end

  defp eventually(server, predicate, attempts \\ 100)
  defp eventually(server, _predicate, 0), do: Boot.status(server)

  defp eventually(server, predicate, attempts) do
    status = Boot.status(server)

    if predicate.(status),
      do: status,
      else:
        (
          Process.sleep(10)
          eventually(server, predicate, attempts - 1)
        )
  end

  defp eventually_probes_finished(server, attempts \\ 150)

  defp eventually_probes_finished(server, 0),
    do: assert(:sys.get_state(server).reconciliation_probes == %{})

  defp eventually_probes_finished(server, attempts) do
    if :sys.get_state(server).reconciliation_probes == %{} do
      :ok
    else
      Process.sleep(10)
      eventually_probes_finished(server, attempts - 1)
    end
  end
end
