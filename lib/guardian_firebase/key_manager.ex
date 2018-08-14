defmodule GuardianFirebase.KeyManager do
  @moduledoc """
  GenServer process for managing Firebase key retrieval and update.
  """

  use GenServer

  alias Poison.Parser

  require Logger

  @key_url "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com"

  def start_link(_arg) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def get_key(id) do
    case :ets.lookup(:firebase_keys, id) do
      [{^id, key}] -> {:ok, key}
      [] -> {:error, :no_key}
    end
  end

  def local_keys do
    Application.get_env(:guardian_firebase, :local_keys)
  end

  def force_reload do
    GenServer.call(__MODULE__, :reload_keys)
  end

  def init(_) do
    _ = :ets.new(:firebase_keys, [:protected, :named_table])

    if Application.get_env(:guardian_firebase, :load_keys_on_startup) do
      reload_keys()
    end

    local_keys()
    |> Enum.map(fn {a, b, _} -> {a, b} end)
    |> load_keys()

    {:ok, nil}
  end

  def handle_call(:reload_keys, _from, _state) do
    reload_keys()
    {:reply, :ok, nil}
  end

  def handle_info(:reload_keys, _state) do
    reload_keys()
    {:noreply, nil}
  end

  defp reload_keys do
    case :hackney.get(@key_url, [], "", []) do
      {:ok, 200, headers, client} ->
        update_keys(headers, client)

      other ->
        :ok = Logger.warn("Error getting Firebase keys: #{inspect(other)}")
        set_reload(10)
    end
  end

  defp update_keys(headers, client) do
    {:ok, body} = :hackney.body(client)

    body
    |> Parser.parse!()
    |> load_keys()
    |> remove_old_keys()

    set_reload_from_header(headers)
  end

  defp load_keys(keys) do
    Enum.each(keys, &:ets.insert(:firebase_keys, &1))
    keys
  end

  defp remove_old_keys(keys) do
    all_keys =
      :firebase_keys
      |> :ets.tab2list()
      |> Enum.unzip()
      |> elem(0)

    new_keys =
      keys
      |> Enum.unzip()
      |> elem(0)

    expired_keys = all_keys -- new_keys
    Enum.each(expired_keys, &:ets.delete(:firebase_keys, &1))
  end

  defp set_reload_from_header(headers) when is_list(headers) do
    possible_headers = ["Cache-Control", "cache-control"]

    Enum.take_while(possible_headers, fn h ->
      case :proplists.get_value(h, headers) do
        :undefined ->
          true
        header ->
          set_reload_from_header(header)
          false
      end
    end)
  end

  defp set_reload_from_header(header) do
    header
    |> String.split(", ")
    |> Enum.find(&String.match?(&1, ~r/max-age=.*/))
    |> String.split("=")
    |> Enum.at(1)
    |> String.to_integer()
    |> set_reload()
  end

  defp set_reload(seconds) do
    Process.send_after(self(), :reload_keys, :timer.seconds(seconds))
  end
end
