defmodule Boson.SystemAction do
  @moduledoc false

  @default_path "/run/boson/action"
  @max_bytes 16
  @payloads %{reboot: "reboot\n", poweroff: "poweroff\n"}

  def default_path, do: @default_path

  def write(action, path \\ @default_path) do
    case Map.fetch(@payloads, action) do
      :error -> {:error, :unsupported_action}
      {:ok, payload} -> write_payload(path, payload)
    end
  end

  def read(path \\ @default_path) do
    case File.open(path, [:read, :binary]) do
      {:error, :enoent} ->
        :missing

      {:error, reason} ->
        {:error, reason}

      {:ok, io} ->
        try do
          case IO.binread(io, @max_bytes + 1) do
            :eof -> {:error, :invalid_action}
            {:error, reason} -> {:error, reason}
            payload when byte_size(payload) > @max_bytes -> {:error, :too_large}
            "reboot\n" -> {:ok, :reboot}
            "poweroff\n" -> {:ok, :poweroff}
            _ -> {:error, :invalid_action}
          end
        after
          File.close(io)
        end
    end
  end

  defp write_payload(path, payload) do
    temp =
      "#{path}.#{System.os_time(:nanosecond)}.#{System.unique_integer([:positive, :monotonic])}.tmp"

    with :ok <- File.mkdir_p(Path.dirname(path)),
         {:ok, io} <- File.open(temp, [:write, :binary, :exclusive]) do
      try do
        with :ok <- IO.binwrite(io, payload),
             :ok <- :file.sync(io),
             :ok <- File.chmod(temp, 0o600),
             :ok <- File.rename(temp, path) do
          :ok
        end
      after
        File.close(io)
        File.rm(temp)
      end
    end
  end
end
