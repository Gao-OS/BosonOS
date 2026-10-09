defmodule Boson.Boot do
  @moduledoc """
  Coordinates runtime boot milestones after Gluon launches the OTP release.
  """

  use GenServer

  require Logger

  alias Boson.SystemAction

  def new_epoch(clock \\ fn -> System.system_time(:millisecond) end) do
    epoch = {__MODULE__, make_ref()}

    :persistent_term.put(epoch, %{
      started_at_ms: clock.(),
      ready_at_ms: nil,
      ready_emitted?: false
    })

    epoch
  end

  def delete_epoch(epoch) do
    :persistent_term.erase(epoch)
    :ok
  end

  def start_link(opts) do
    {name, init_opts} = Keyword.pop(opts, :name, __MODULE__)

    case name do
      nil -> GenServer.start_link(__MODULE__, init_opts)
      registered -> GenServer.start_link(__MODULE__, init_opts, name: registered)
    end
  end

  def status(server \\ __MODULE__), do: GenServer.call(server, :status)

  def component_ready(component, pid, server \\ __MODULE__),
    do: GenServer.call(server, {:component_ready, component, pid})

  def request_action(action, server \\ __MODULE__),
    do: GenServer.call(server, {:request_action, action})

  @impl true
  def init(opts) do
    Logger.info("Boson.Boot online")

    state = %{
      phase: :starting,
      epoch: Keyword.fetch!(opts, :epoch),
      required: MapSet.new(Keyword.fetch!(opts, :required_components)),
      components: %{},
      reconciliation_probes: %{},
      action_path: Keyword.get(opts, :action_path, SystemAction.default_path()),
      shutdown: Keyword.get(opts, :shutdown, &System.stop/1),
      test_action: Keyword.get(opts, :test_action),
      last_action: nil
    }

    case SystemAction.read(state.action_path) do
      :missing ->
        {:ok, state, {:continue, :reconcile}}

      {:ok, action} ->
        Logger.info("Boson.Runtime stopping action=#{action}")
        send(self(), {:shutdown, 0})
        {:ok, %{state | phase: :stopping, last_action: action}}

      {:error, reason} ->
        Logger.error("Boson.Runtime invalid pending action reason=#{inspect(reason)}")
        send(self(), {:shutdown, 1})
        {:ok, %{state | phase: :stopping}}
    end
  end

  @impl true
  def handle_continue(:reconcile, state) do
    boot = self()

    probes =
      Enum.reduce(state.required, %{}, fn component, probes ->
        case Process.whereis(component) do
          nil ->
            probes

          pid ->
            ref = make_ref()

            spawn(fn ->
              result =
                try do
                  GenServer.call(pid, :boson_readiness, 1_000)
                catch
                  :exit, reason -> {:error, reason}
                end

              send(boot, {:reconcile_result, ref, component, pid, result})
            end)

            Map.put(probes, ref, {component, pid})
        end
      end)

    {:noreply, maybe_ready(%{state | reconciliation_probes: probes})}
  end

  @impl true
  def handle_call(:status, _from, state) do
    epoch = :persistent_term.get(state.epoch)
    online = Map.keys(state.components) |> Enum.sort_by(&inspect/1)
    missing = state.required |> MapSet.difference(MapSet.new(online)) |> Enum.sort_by(&inspect/1)

    status = %{
      phase: state.phase,
      started_at_ms: epoch.started_at_ms,
      ready_at_ms: epoch.ready_at_ms,
      online_components: online,
      missing_components: missing,
      last_action: state.last_action
    }

    {:reply, status, state}
  end

  def handle_call({:component_ready, component, pid}, {caller, _tag}, state) do
    cond do
      not MapSet.member?(state.required, component) ->
        Logger.warning("Boson.Runtime unexpected component=#{inspect(component)}")
        {:reply, {:error, :unexpected_component}, state}

      caller != pid or Process.whereis(component) != pid ->
        {:reply, {:error, :identity_mismatch}, state}

      true ->
        {:reply, :ok, state |> record_component(component, pid) |> maybe_ready()}
    end
  end

  def handle_call({:request_action, action}, _from, state) do
    {result, state} = select_action(action, state)
    {:reply, result, state}
  end

  @impl true
  def handle_info({:reconcile_result, ref, component, pid, result}, state) do
    {candidate, probes} = Map.pop(state.reconciliation_probes, ref)
    state = %{state | reconciliation_probes: probes}

    if state.phase != :stopping and candidate == {component, pid} and
         result == {:ready, component, pid} and Process.whereis(component) == pid do
      {:noreply, state |> record_component(component, pid) |> maybe_ready()}
    else
      {:noreply, state}
    end
  end

  def handle_info({:DOWN, ref, :process, pid, reason}, state) do
    case Enum.find(state.components, fn {_component, entry} ->
           entry.pid == pid and entry.ref == ref
         end) do
      nil ->
        {:noreply, state}

      {component, _entry} ->
        Logger.warning(
          "Boson.Runtime unavailable component=#{inspect(component)} reason=#{inspect(reason)}"
        )

        phase = if state.phase == :ready, do: :starting, else: state.phase
        {:noreply, %{state | phase: phase, components: Map.delete(state.components, component)}}
    end
  end

  def handle_info({:shutdown, code}, state) do
    state.shutdown.(code)
    {:noreply, state}
  end

  def handle_info({:test_action, action}, state) do
    {_result, state} = select_action(action, state)
    {:noreply, state}
  end

  defp record_component(state, component, pid) do
    case Map.get(state.components, component) do
      %{pid: ^pid} ->
        state

      previous ->
        if previous, do: Process.demonitor(previous.ref, [:flush])
        entry = %{pid: pid, ref: Process.monitor(pid)}
        %{state | components: Map.put(state.components, component, entry)}
    end
  end

  defp maybe_ready(%{phase: :starting} = state) do
    if MapSet.equal?(state.required, MapSet.new(Map.keys(state.components))) do
      epoch = :persistent_term.get(state.epoch)

      if epoch.ready_emitted? do
        Logger.info("Boson.Runtime recovered")
      else
        :persistent_term.put(state.epoch, %{
          epoch
          | ready_at_ms: System.system_time(:millisecond),
            ready_emitted?: true
        })

        Logger.info("Boson.Runtime ready")

        if state.test_action,
          do: Process.send_after(self(), {:test_action, state.test_action}, 100)
      end

      %{state | phase: :ready}
    else
      state
    end
  end

  defp maybe_ready(state), do: state

  defp select_action(action, state) when action not in [:reboot, :poweroff],
    do: {{:error, :unsupported_action}, state}

  defp select_action(_action, %{phase: :starting} = state), do: {{:error, :not_ready}, state}

  defp select_action(_action, %{phase: :stopping} = state),
    do: {{:error, :already_stopping}, state}

  defp select_action(action, %{phase: :ready} = state) do
    case SystemAction.write(action, state.action_path) do
      :ok ->
        Logger.info("Boson.Runtime stopping action=#{action}")
        send(self(), {:shutdown, 0})
        {:ok, %{state | phase: :stopping, last_action: action}}

      {:error, _reason} = error ->
        {error, state}
    end
  end
end
