defmodule GuardianFirebaseTest do
  use ExUnit.Case
  doctest GuardianFirebase

  defmodule Impl do
    use GuardianFirebase,
      otp_app: :guardian_firebase,
      project_id: "testapp"

    def subject_for_token(resource, _claims), do: {:ok, resource}
    def resource_from_claims(claims), do: {:ok, claims["sub"]}
  end

  describe "token generation" do
    setup do
      {:ok, token, claims} = Impl.encode_and_sign("test")
      {:ok, claims: claims, token: token}
    end

    test "subject is preserved", %{claims: claims} do
      assert claims["sub"] == "test"
    end

    test "token validates", %{token: token, claims: claims} do
      assert {:ok, "test", new_claims} = Impl.resource_from_token(token)
      assert new_claims == claims
    end
  end
end
