defmodule Boson.SupervisorTest do
  use ExUnit.Case, async: true

  test "starts the initial BosonOS control-plane services" do
    pid = start_supervised!(Boson.Supervisor)

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
  end
end
