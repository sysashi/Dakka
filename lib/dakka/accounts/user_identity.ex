defmodule Dakka.Accounts.UserIdentity do
  use Ecto.Schema

  import Ecto.Changeset

  @discord "discord"

  schema "users_identities" do
    field :provider, :string
    field :provider_id, :string
    field :provider_token, :string
    field :provider_meta, :map, default: %{}

    belongs_to :user, Dakka.Accounts.User
  end

  def discord_registration_changeset(user_info, token) do
    params = %{
      provider_id: user_info["id"],
      provider_token: token,
      provider_meta: user_info
    }

    %__MODULE__{provider: @discord}
    |> cast(params, [
      :provider_id,
      :provider_meta,
      :provider_token
    ])
    |> validate_required([:provider_id, :provider_token])
  end
end
