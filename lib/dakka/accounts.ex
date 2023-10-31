defmodule Dakka.Accounts do
  @moduledoc """
  The Accounts context.
  """

  @pubsub Dakka.PubSub

  import Ecto.Query, warn: false

  alias Ecto.Multi

  alias Dakka.{Repo, Scope}

  alias Dakka.Accounts.{
    User,
    UserToken,
    UserNotifier,
    UserSettings,
    UserNotification,
    UserGameCharacter
  }

  alias Dakka.Accounts.Events.UserSettingsUpdated

  def subscribe(%Scope{current_user: %User{} = user}) do
    Phoenix.PubSub.subscribe(@pubsub, topic(user))
  end

  def broadcast(%UserNotification{user: user} = event), do: broadcast(user, event)
  def broadcast(%UserSettingsUpdated{user: user} = event), do: broadcast(user, event)

  def broadcast(users, event) when is_list(users) do
    for user <- users do
      broadcast(user, event)
    end
  end

  def broadcast(user, event) do
    Phoenix.PubSub.broadcast(
      @pubsub,
      topic(user),
      {__MODULE__, event}
    )
  end

  def topic(%User{} = user), do: "user_events:#{user.id}"

  ## Settings

  def change_user_settings(%Scope{} = scope, attrs \\ %{}) do
    UserSettings.changeset(scope.current_user.settings, attrs)
  end

  def update_user_settings(%Scope{} = scope, attrs) do
    changeset = User.settings_changeset(scope.current_user, attrs)

    with {:ok, user} <- Repo.update(changeset) do
      broadcast(user, %UserSettingsUpdated{user: user})
      {:ok, user}
    end
  end

  ## Notifications

  def list_user_notifications(scope, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)

    UserNotification
    |> where(user_id: ^scope.current_user_id)
    |> where(^build_filters(opts))
    |> limit(^limit)
    |> offset(^offset)
    |> preload([:listing, :offer])
    |> Repo.all()
  end

  def count_notifications(scope, opts \\ []) do
    UserNotification
    |> where(user_id: ^scope.current_user_id)
    |> where(^build_filters(opts))
    |> Repo.aggregate(:count, :id)
  end

  def count_notifications_by_action(scope, opts) do
    UserNotification
    |> where(user_id: ^scope.current_user_id)
    |> where(^build_filters(opts))
    |> group_by([n], n.action)
    |> select([n], {n.action, count(n)})
    |> Repo.all()
    |> Enum.into(%{})
  end

  def notifications_query(scope, opts \\ []) do
    UserNotification
    |> where(user_id: ^scope.current_user_id)
    |> where(^build_filters(opts))
  end

  defp build_filters(filters) do
    Enum.reduce(filters, true, fn
      {key, value}, dynamic when key in [:status, :actions] ->
        dynamic(^dynamic and ^notifications_filter(key, value))

      _, dynamic ->
        dynamic
    end)
  end

  defp notifications_filter(:status, :unread), do: dynamic([n], is_nil(n.read_at))
  defp notifications_filter(:status, :read), do: dynamic([n], not is_nil(n.read_at))
  defp notifications_filter(:status, _), do: dynamic(true)
  defp notifications_filter(:actions, []), do: dynamic(true)
  defp notifications_filter(:actions, actions), do: dynamic([n], n.action in ^actions)

  ##

  def get_users_map(ids) do
    User
    |> where([u], u.id in ^ids)
    |> select([u], {u.id, u})
    |> Repo.all()
    |> Map.new()
  end

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  def get_user_by_username_and_password(username, password)
      when is_binary(username) and is_binary(password) do
    user = Repo.get_by(User, username: username)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Ecto.Changeset.put_embed(:settings, UserSettings.default())
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user_registration(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs,
      hash_password: false,
      validate_email: true,
      validate_username: true
    )
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}) do
    User.email_changeset(user, attrs, validate_email: false)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_user_email(user, "valid password", %{email: ...})
      {:ok, %User{}}

      iex> apply_user_email(user, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_user_email(user, password, attrs) do
    user
    |> User.email_changeset(attrs)
    |> User.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
         %UserToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(user_email_multi(user, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp user_email_multi(user, email, context) do
    changeset =
      user
      |> User.email_changeset(%{email: email})
      |> User.confirm_changeset()

    Multi.new()
    |> Multi.update(:user, changeset)
    |> Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, [context]))
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm_email/#{&1})")
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}) do
    User.password_changeset(user, attrs, hash_password: false)
  end

  @doc """
  Updates the user password.

  ## Examples

      iex> update_user_password(user, "valid password", %{password: ...})
      {:ok, %User{}}

      iex> update_user_password(user, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, password, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> User.validate_current_password(password)

    Multi.new()
    |> Multi.update(:user, changeset)
    |> Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(UserToken.token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc ~S"""
  Delivers the confirmation email instructions to the given user.

  ## Examples

      iex> deliver_user_confirmation_instructions(user, &url(~p"/users/confirm/#{&1}"))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_user_confirmation_instructions(confirmed_user, &url(~p"/users/confirm/#{&1}"))
      {:error, :already_confirmed}

  """
  def deliver_user_confirmation_instructions(%User{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, user_token} = UserToken.build_email_token(user, "confirm")
      Repo.insert!(user_token)
      UserNotifier.deliver_confirmation_instructions(user, confirmation_url_fun.(encoded_token))
    end
  end

  @doc """
  Confirms a user by the given token.

  If the token matches, the user account is marked as confirmed
  and the token is deleted.
  """
  def confirm_user(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "confirm"),
         %User{} = user <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transaction(confirm_user_multi(user)) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  defp confirm_user_multi(user) do
    Multi.new()
    |> Multi.update(:user, User.confirm_changeset(user))
    |> Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, ["confirm"]))
  end

  ## Reset password

  @doc ~S"""
  Delivers the reset password email to the given user.

  ## Examples

      iex> deliver_user_reset_password_instructions(user, &url(~p"/users/reset_password/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_reset_password_instructions(%User{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "reset_password")
    Repo.insert!(user_token)
    UserNotifier.deliver_reset_password_instructions(user, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the user by reset password token.

  ## Examples

      iex> get_user_by_reset_password_token("validtoken")
      %User{}

      iex> get_user_by_reset_password_token("invalidtoken")
      nil

  """
  def get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reset_password"),
         %User{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Resets the user password.

  ## Examples

      iex> reset_user_password(user, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %User{}}

      iex> reset_user_password(user, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_user_password(user, attrs) do
    Multi.new()
    |> Multi.update(:user, User.password_changeset(user, attrs))
    |> Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  ## User Game Characters

  def list_user_characters(%Scope{} = scope) do
    UserGameCharacter
    |> where(user_id: ^scope.current_user_id)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  def user_character_options(%Scope{} = scope) do
    UserGameCharacter
    |> where(user_id: ^scope.current_user_id)
    |> order_by(desc: :inserted_at)
    |> select([c], {fragment("format('%s%s', ?, ' (' || ? || ')')", c.name, c.class), c.id})
    |> Repo.all()
  end

  def get_user_character!(%Scope{} = scope, id) do
    UserGameCharacter
    |> where(id: ^id)
    |> where(user_id: ^scope.current_user_id)
    |> Repo.one!()
  end

  def create_user_character(%Scope{} = scope, attrs) do
    character = %UserGameCharacter{user_id: scope.current_user_id}

    character
    |> UserGameCharacter.changeset(attrs)
    |> Repo.insert()
  end

  def update_user_character(%Scope{} = _scope, %UserGameCharacter{} = char, attrs) do
    char
    |> UserGameCharacter.changeset(attrs)
    |> Repo.update()
  end

  def delete_user_character(%Scope{} = scope, char_id) do
    char = get_user_character!(scope, char_id)

    listings_query =
      Dakka.Market.Listing
      |> join(:inner, [l], s in assoc(l, :seller))
      |> where([l], l.user_game_character_id == ^char_id)
      |> where([l, s], s.id == ^scope.current_user_id)
      |> select([l], l)

    multi =
      Multi.new()
      |> Multi.update_all(:listings, listings_query, set: [quick_sell: false])
      |> Multi.delete(:character, char)

    case Repo.transaction(multi) do
      {:ok, %{character: char, listings: {_, listings}}} ->
        listings
        |> Enum.map(&%Dakka.Market.Events.ListingUpdated{listing: &1})
        |> tap(fn events -> Enum.each(events, &Dakka.Market.Public.broadcast(&1)) end)
        |> tap(fn events -> Enum.each(events, &Dakka.Market.broadcast!(scope, &1)) end)

        {:ok, char}

      {:error, :character, changeset, _changes} ->
        {:error, changeset}
    end
  end

  def change_user_character(character, attrs \\ %{}) do
    UserGameCharacter.changeset(character, attrs, validate_name: false)
  end
end
