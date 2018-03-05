defmodule GuardianFirebase.TokenTest do
  use ExUnit.Case, async: true

  alias GuardianFirebase.Token
  alias Timex.Duration

  defmodule Impl do
    use GuardianFirebase,
      otp_app: :guardian_firebase,
      project_id: "testapp"

    def subject_for_token(resource, _claims), do: {:ok, resource}
    def resource_from_claims(claims), do: {:ok, claims["sub"]}
  end

  describe "claims verification" do
    setup do
      {:ok, claims} = Token.build_claims(Impl, "test", "test")
      {:ok, claims: claims}
    end

    test "should pass with valid claims", %{claims: claims} do
      assert {:ok, _} = Token.verify_claims(Impl, claims, [])
    end

    test "should fail if the expiry date is in the past", ctx do
      exp =
        DateTime.utc_now()
        |> Timex.subtract(Duration.from_days(1))
        |> Timex.to_unix()

      claims = Map.put(ctx.claims, "exp", exp)

      assert {:error, _} = Token.verify_claims(Impl, claims, [])
    end

    test "should fail if the issue date is in the future", ctx do
      iat =
        DateTime.utc_now()
        |> Timex.add(Duration.from_days(1))
        |> Timex.to_unix()

      claims = Map.put(ctx.claims, "iat", iat)

      assert {:error, _} = Token.verify_claims(Impl, claims, [])
    end

    test "should fail if the audience is not correct", ctx do
      claims = Map.put(ctx.claims, "aud", "NotCorrect")

      assert {:error, _} = Token.verify_claims(Impl, claims, [])
    end

    test "should fail if the issuer is incorrect", ctx do
      claims = Map.put(ctx.claims, "iss", "https://bogus/issuer")

      assert {:error, _} = Token.verify_claims(Impl, claims, [])
    end
  end

  describe "sanity check" do
    test "custom claims should persist" do
      {:ok, token} = Token.create_token(Impl, %{"foo" => 1}, [])
      assert %{claims: %{"foo" => 1}} = Token.peek(Impl, token)
    end
  end
end
