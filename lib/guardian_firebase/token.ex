defmodule GuardianFirebase.Token do
  @moduledoc "Implements Guardian's Token behavior for Firebase tokens"

  @behaviour Guardian.Token

  alias Guardian.Token.Jwt
  alias GuardianFirebase.{KeyManager, Verify}
  alias JOSE.{JWK, JWS, JWT}

  import Guardian, only: [stringify_keys: 1]

  @doc """
  Inspect the JWT without any validation or signature checking.
  Return an map with keys: `headers` and `claims`
  """
  def peek(mod, token), do: Jwt.peek(mod, token)

  @doc """
  Generate unique token id
  """
  def token_id do
    10
    |> :crypto.strong_rand_bytes()
    |> Base.encode16()
  end

  @doc """
  Create a token. Uses the claims, encodes and signs the token.
  The signing secret will be found first from the options.
  If not specified the secret key from the configuration will be used.
  Configuration:
  * `secret_key` The secret key to use for signing
  Options:
  * `secret` The secret key to use for signing
  * `headers` The Jose headers that should be used
  The secret may be in the form of any resolved value from `Guardian.Config`
  """
  def create_token(mod, claims, options \\ []) do
    {key_id, key} = fetch_signing_key(mod, options)

    {_, token} =
      key
      |> jose_jwk()
      |> JWT.sign(jose_jws(mod, key_id, options), claims)
      |> JWS.compact()

    {:ok, token}
  end

  @doc """
  Builds the default claims for all new Firebase tokens.
  """
  # credo:disable-for-next-line /\.Warning\./
  def build_claims(mod, _resource, sub, claims \\ %{}, options \\ []) do
    claims =
      claims
      |> stringify_keys()
      |> set_jti()
      |> set_iat()
      |> set_iss(mod, options)
      |> set_aud(mod, options)
      |> set_sub(mod, sub, options)
      |> set_ttl(mod, options)

    {:ok, claims}
  end

  @doc """
  Decodes the token and validates the signature.
  """
  def decode_token(mod, token, options \\ []) do
    headers = JWT.peek_protected(token).fields
    key_id = headers["kid"]
    algos = Application.get_env(:guardian_firebase, :allowed_algos)

    verify_result =
      mod
      |> fetch_verify_key(key_id, options)
      |> jose_jwk()
      |> JWT.verify_strict(algos, token)

    case verify_result do
      {true, jose_jwt, _} -> {:ok, jose_jwt.fields}
      {false, _, _} -> {:error, :invalid_token}
    end
  end

  @doc """
  Verifies the claims.
  """
  def verify_claims(mod, claims, options) do
    opts = Keyword.put(options, :token_verify_module, Verify)
    Jwt.verify_claims(mod, claims, opts)
  end

  @doc """
  Revoking a Firebase token does not do anything.
  """
  def revoke(_mod, _claims, _token, _options), do: {:error, :not_implemented}

  @doc """
  Refreshing a Firebase token is not implemented.
  """
  def refresh(_mod, _old_token, _options), do: {:error, :not_implemented}

  @doc """
  Exchanging a Firebase token is not implemented.
  """
  def exchange(_mod, _old_token, _from_type, _to_type, _options),
    do: {:error, :not_implemented}

  defp jose_jws(_mod, key_id, opts) do
    headers = Keyword.get(opts, :headers, %{})
    algo = hd(Application.get_env(:guardian_firebase, :allowed_algos))
    Map.merge(headers, %{"alg" => algo, "kid" => key_id})
  end

  defp jose_jwk(value), do: JWK.from_pem(value)

  defp fetch_signing_key(mod, opts) do
    key_id = Keyword.get(opts, :secret_key_id)
    fetch_signing_key(mod, key_id, opts)
  end

  defp fetch_signing_key(_mod, nil, _opts) do
    case KeyManager.local_keys() do
      [] -> raise "No secret keys loaded for JWT signing"
      [{key_id, _, key} | _] -> {key_id, key}
    end
  end

  defp fetch_signing_key(_mod, key_id, _opts) do
    key =
      KeyManager.local_keys()
      |> List.keyfind(key_id, 0)

    case key do
      nil -> raise "JWT Signing key not loaded"
      key -> {key_id, key}
    end
  end

  defp fetch_verify_key(_mod, key_id, _opts) do
    case KeyManager.get_key(key_id) do
      {:ok, key} -> key
      {:error, _} -> raise "JWT Verify key not loaded"
    end
  end

  defp set_sub(claims, _mod, subject, _opts),
    do: Map.put(claims, "sub", subject)

  defp set_iat(claims) do
    ts = Guardian.timestamp()
    claims |> Map.put("iat", ts) |> Map.put("nbf", ts - 1)
  end

  defp set_ttl(%{"iat" => iat_v} = claims, _mod, _opts),
    do: Map.put(claims, "exp", iat_v + 60 * 60)

  defp set_iss(claims, mod, _opts) do
    issuer_prefix = Application.get_env(:guardian_firebase, :issuer_prefix)
    project_id = mod |> apply(:config, [:project_id]) |> to_string()
    Map.put(claims, "iss", issuer_prefix <> project_id)
  end

  defp set_aud(claims, mod, _opts) do
    project_id = mod |> apply(:config, [:project_id]) |> to_string()
    Map.put(claims, "aud", project_id)
  end

  defp set_jti(claims), do: Map.put(claims, "jti", token_id())
end
