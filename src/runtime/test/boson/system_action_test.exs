defmodule Boson.SystemActionTest do
  use ExUnit.Case, async: true
  import Bitwise
  alias Boson.SystemAction
  @moduletag :tmp_dir

  setup %{tmp_dir: root}, do: %{path: Path.join(root, "boson/action")}

  test "uses bounded protocol defaults" do
    assert SystemAction.default_path() == "/run/boson/action"
  end

  for {action, payload} <- [reboot: "reboot\n", poweroff: "poweroff\n"] do
    test "atomically writes exact private #{action} payload", %{path: path} do
      assert :ok = SystemAction.write(unquote(action), path)
      assert File.read!(path) == unquote(payload)
      assert band(File.stat!(path).mode, 0o777) == 0o600
      assert {:ok, unquote(action)} = SystemAction.read(path)
      assert File.ls!(Path.dirname(path)) == ["action"]
    end
  end

  test "rejects unsupported actions without touching files", %{path: path} do
    assert {:error, :unsupported_action} = SystemAction.write(:halt, path)
    refute File.exists?(Path.dirname(path))
  end

  test "distinguishes missing, malformed, and oversized actions", %{path: path} do
    assert :missing = SystemAction.read(path)
    File.mkdir_p!(Path.dirname(path))

    for payload <- ["", "reboot", "reboot\n\n", "poweroff now\n", String.duplicate("x", 16)] do
      File.write!(path, payload)
      assert {:error, :invalid_action} = SystemAction.read(path)
    end

    for size <- [17, 1024] do
      File.write!(path, String.duplicate("x", size))
      assert {:error, :too_large} = SystemAction.read(path)
    end
  end

  test "preserves concrete read and parent-write errors", %{path: path} do
    File.write!(Path.dirname(path), "not a directory")
    assert {:error, :enotdir} = SystemAction.read(path)
    assert {:error, :eexist} = SystemAction.write(:reboot, path)
    assert File.read!(Path.dirname(path)) == "not a directory"
  end

  test "cleans temporary file after rename failure", %{path: path} do
    File.mkdir_p!(path)
    assert {:error, :eisdir} = SystemAction.write(:poweroff, path)
    assert File.ls!(Path.dirname(path)) == ["action"]
  end

  test "replaces prior action without residual files", %{path: path} do
    assert :ok = SystemAction.write(:reboot, path)
    assert :ok = SystemAction.write(:poweroff, path)
    assert File.read!(path) == "poweroff\n"
    assert File.ls!(Path.dirname(path)) == ["action"]
  end
end
