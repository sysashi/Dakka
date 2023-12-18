defmodule DakkaWeb.OauthCallbackController do
  use DakkaWeb, :controller
  require Logger

  def new(conn, %{"provider" => provider, "code" => code}) do
    client = client(provider)
    client_config = client.config()

    with {:ok, access_token} <- client.exchange_code(code, client_config),
         {:ok, user_info} <- client.fetch_user_info(access_token),
         {:ok, user} <- Dakka.Accounts.register_discord_user(user_info, access_token) do
      conn
      |> put_flash(:info, "Welcome #{user.username}")
      |> DakkaWeb.UserAuth.log_in_user(user)
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.debug("failed Discord insert #{inspect(changeset.errors)}")

        conn
        |> put_flash(
          :error,
          "We were unable to fetch the necessary information from your Discord account"
        )
        |> redirect(to: "/")

      {:error, reason} ->
        Logger.debug("failed Discord exchange #{inspect(reason)}")

        conn
        |> put_flash(:error, "We were unable to contact Discord. Please try again later")
        |> redirect(to: "/")
    end
  end

  def new(conn, %{"provider" => _, "error" => _}) do
    redirect(conn, to: "/")
  end

  defp client("discord"), do: Dakka.Oauth.DiscordClient
end
