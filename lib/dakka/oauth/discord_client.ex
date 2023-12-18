defmodule Dakka.Oauth.DiscordClient do
  @authorize_url "https://discord.com/oauth2/authorize"
  @token_url "https://discord.com/api/oauth2/token"
  @user_info_url "https://discord.com/api/v10/users/@me"

  def log_in_url() do
    config() |> Keyword.new() |> authorize_url()
  end

  def authorize_url(opts) do
    opts =
      opts
      |> Keyword.put_new(:response_type, "code")
      |> Keyword.put_new(:scope, "identify email")
      |> Keyword.put_new(:prompt, "consent")

    query = URI.encode_query(opts)

    @authorize_url
    |> URI.new!()
    |> URI.append_query(query)
    |> URI.to_string()
  end

  def exchange_code(code, config) do
    request_opts = [
      auth: {:basic, "#{config.client_id}:#{config.client_secret}"},
      form: [
        grant_type: "authorization_code",
        code: code,
        redirect_uri: config.redirect_uri
      ]
    ]

    with {:ok, %{body: %{"access_token" => access_token}}} <- Req.post(@token_url, request_opts) do
      {:ok, access_token}
    else
      {:error, _reason} = error -> error
      response -> {:error, {:bad_response, response}}
    end
  end

  def fetch_user_info(access_token) do
    with {:ok, %{status: 200, body: user_info}} <-
           Req.get(@user_info_url, auth: {:bearer, access_token}) do
      {:ok, user_info}
    else
      {:error, _reason} = error -> error
      response -> {:error, {:bad_response, response}}
    end
  end

  def config() do
    Application.get_env(:dakka, :oauth, [])
    |> Keyword.fetch!(:discord)
    |> Map.new()
  end
end
