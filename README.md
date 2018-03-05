# GuardianFirebase

This library extends [Guardian](https://github.com/ueberauth/guardian) so that
it can validate tokens issued by
[Google Firebase Auth](https://firebase.google.com/docs/auth/).

## Installation

Before starting, please read the
[Guardian documentation](https://hexdocs.pm/guardian) to familiarize yourself
with the basic `Guardian` concepts.

First, add `guardian_firebase` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:guardian_firebase, "~> 0.1.0"}]
end
```

Then you must create the required `Guardian` "Implementation Module". The
difference is that you will `use GuardianFirebase` instead of `Guardian`.

```elixir
defmodule MyApp.Guardian do
  use GuardianFirebase, otp_app: :my_app, project_id: "my-firebase-project"

  def subject_for_token(resource, _claims) do
    # This function should only be used in testing since GuardianFirebase does
    # not generate legitimate Firebase tokens. Return the Firebase User ID from
    # this function so that `resource_from_claims/1` will work properly.
    {:ok, resource.firebase_id}
  end

  def resource_from_claims(claims) do
    # Here we'll look up our resource from the claims, the subject can be
    # found in the `"sub"` key. In `above subject_for_token/2` we returned
    # the Firebase id so here we'll rely on that to look it up.
    id = claims["sub"]
    resource = MyApp.get_resource_by_firebase_id(id)
    {:ok, resource}
  end
end
```
The `:otp_app` is required by `Guardian`, and the `:project_id` is your
applications's Firebase ID. This is all you should need to have a working
installation.

Most of the configuration allowed by `Guardian` is not needed, or even possible.
with `GuardianFirebase`.

## Testing

`GuardianFirebase` can generate tokens that are identical in structure to those
issued by Firebase, but that are signed by a different key. This allows you to
generate keys for testing without having to get keys from Firebase.

To generate tokens, you have to tell `GuardianFirebase` what keys to use to sign
the tokens. Add the following lines to `config/test.exs`:

```elixir
config :guardian_firebase,
  load_keys_on_startup: false,
  local_keys: [
    {
      "some-key-id",
      """
      public_key_pem_data
      """,
      """
      private_key_pem_data
      """
    }
  ]
```

The `:load_keys_on_startup` value tells `GuardianFirebase` whether or not it
should load the official Firebase keys on startup. For testing, we want to avoid
contacting the Firebase servers.

The `:local_keys` value is a list of 3-element tuples that contain a key ID,
public key and private key. The public and private keys need to be valid
PEM-encoded data. Generating the keypair is left as an exercise for the reader.
