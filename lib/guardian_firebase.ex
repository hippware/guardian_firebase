defmodule GuardianFirebase do
  @moduledoc """
  Documentation for GuardianFirebase.
  """

  defmacro __using__(opts \\ []) do
    opts =
      opts
      |> Keyword.put(:token_module, GuardianFirebase.Token)
      |> Keyword.put(:token_verify_module, GuardianFirebase.Verify)

    quote do
      use Guardian, unquote(opts)
    end
  end
end
