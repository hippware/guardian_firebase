defmodule GuardianFirebase.Verify do
  @moduledoc "Verifies the claims in a Firebase token."

  use Guardian.Token.Verify

  alias Guardian.Token.Verify
  alias Guardian.Token.Jwt.Verify, as: Base

  @doc false
  def verify_claim(mod, "iss", %{"iss" => iss} = claims, _opts) do
    issuer_prefix = Application.get_env(:guardian_firebase, :issuer_prefix)
    project_id = apply(mod, :config, [:project_id])

    if iss == issuer_prefix <> project_id do
      {:ok, claims}
    else
      {:error, :invalid_issuer}
    end
  end

  @doc false
  def verify_claim(mod, "aud", %{"aud" => aud} = claims, _opts) do
    project_id = apply(mod, :config, [:project_id])

    if aud == project_id do
      {:ok, claims}
    else
      {:error, :invalid_audience}
    end
  end

  @doc false
  def verify_claim(mod, "iat", %{"iat" => iat} = claims, _opts) do
    if Verify.time_within_drift?(mod, iat) || iat <= Guardian.timestamp() do
      {:ok, claims}
    else
      {:error, :future_issue_date}
    end
  end

  @doc false
  def verify_claim(mod, claim_key, claims, opts),
    do: Base.verify_claim(mod, claim_key, claims, opts)
end
