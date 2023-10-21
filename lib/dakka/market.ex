defmodule Dakka.Market do
  @moduledoc """
  M
  """

  @pubsub Dakka.PubSub

  import Ecto.Query

  alias Ecto.Multi

  alias Dakka.Repo
  alias Dakka.Scope
  alias Dakka.Inventory
  alias Dakka.Accounts.User

  alias Dakka.Market.{
    Listing,
    ListingOffer
  }

  alias Dakka.Market.Events.{
    ListingCreated,
    ListingDeleted,
    ListingExpired,
    ListingSold,
    ListingUpdated,
    OfferAccepted,
    OfferCancelled,
    OfferCreated,
    OfferDeclined,
    TradeMessage
  }

  # item base: x
  # rarities
  # property: (key, value | values /required class/)
  # (impl|expl) mod: (key, value)

  def topic(:market), do: "market_events"
  def topic({:market, %User{} = user}), do: "market_events:user:#{user.id}"
  def topic({:listing, %Listing{} = listing}), do: "market_events:listing:#{listing.id}"
  def topic(%ListingOffer{} = offer), do: "market_events:offer:#{offer.id}"

  def subscribe(topic \\ :market) do
    Phoenix.PubSub.subscribe(Dakka.PubSub, topic(topic))
  end

  def send_trade_message(offer, message) do
    event = {__MODULE__, %TradeMessage{message: message}}
    Phoenix.PubSub.broadcast_from(@pubsub, self(), topic(offer), event)
  end

  def active_listing_query() do
    from(l in Listing, as: :listing)
    |> where(status: :active)
    |> where(deleted: false)
  end

  def listings() do
    active_listing_query()
    |> preload(user_game_item: ^Inventory.item_preloads())
    |> Repo.all()
    |> Enum.map(&%{&1 | user_game_item: Inventory.group_strings(&1.user_game_item)})
  end

  def listings_with_buyer_offers(%Scope{} = scope, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)

    preload =
      if scope.current_user do
        offers_query =
          ListingOffer
          |> where(user_id: ^scope.current_user_id)
          |> where([o], o.status in [:active, :accepted_by_seller])

        [offers: offers_query]
      else
        []
      end

    active_listing_query()
    |> order_by(desc: :inserted_at)
    |> preload(user_game_item: ^Inventory.item_preloads())
    |> preload(^preload)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
    |> Enum.map(&%{&1 | user_game_item: Inventory.group_strings(&1.user_game_item)})
  end

  def get_listing!(id, preload \\ []) do
    Listing
    |> where(id: ^id)
    |> preload(^preload)
    |> Repo.one!()
  end

  def get_listing_by_seller_item_id!(%User{} = seller, id) do
    Listing
    |> where(deleted: false)
    |> where([l, i], i.id == ^id)
    |> join(:inner, [l], i in assoc(l, :user_game_item), on: i.user_id == ^seller.id)
    |> join(:inner, [l, i], u in assoc(i, :user))
    |> preload([l, i, u], user_game_item: {i, user: u})
    |> Repo.one!()
  end

  def get_listing_with_buyer_offers!(listing_id, %Scope{} = scope) do
    preload =
      if scope.current_user do
        offers_query =
          ListingOffer
          |> where(user_id: ^scope.current_user_id)
          |> where([o], o.status in [:active, :accepted_by_seller])

        [offers: offers_query]
      else
        []
      end

    listing =
      Listing
      |> where(id: ^listing_id)
      |> where(deleted: false)
      |> preload(user_game_item: ^Inventory.item_preloads())
      |> preload(^preload)
      |> Repo.one!()

    %{
      listing
      | user_game_item: Inventory.group_strings(listing.user_game_item)
    }
  end

  def search_listings(scope, opts) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)
    filters = Keyword.get(opts, :filters, [])

    preload =
      if scope.current_user do
        offers_query =
          ListingOffer
          |> where(user_id: ^scope.current_user_id)
          |> where([o], o.status in [:active, :accepted_by_seller])

        [offers: offers_query]
      else
        []
      end

    active_listing_query()
    |> apply_listing_filters(filters)
    |> order_by(desc: :inserted_at)
    |> preload(user_game_item: ^Inventory.item_preloads())
    |> preload(^preload)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
    |> Enum.map(&%{&1 | user_game_item: Inventory.group_strings(&1.user_game_item)})
  end

  def build_listing(user_item) do
    %Listing{user_game_item_id: user_item.id}
  end

  def change_listing(listing, attrs \\ %{}) do
    Listing.changeset(listing, attrs)
  end

  # item listing created ->
  #   item owner - {:market, user_id}
  #   market - :market
  #
  # item listings (updated | deleted | sold | expired) ->
  #  item owner - {:market, user_id}
  #  market - :market
  #  users with offers {:listing, listing_id}
  #

  def create_listing(listing, attrs) do
    changeset = Listing.changeset(listing, attrs)

    case Repo.insert(changeset) do
      {:ok, listing} ->
        listing =
          Repo.preload(listing, user_game_item: Inventory.item_preloads(), user_game_item: :user)

        listing = %{
          listing
          | user_game_item: Inventory.group_strings(listing.user_game_item)
        }

        broadcast(
          [
            :market,
            market: listing.user_game_item.user
          ],
          %ListingCreated{listing: listing}
        )

        {:ok, listing}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def edit_listing(listing, attrs) do
    changeset = Listing.changeset(listing, attrs)

    prev_query =
      Listing
      |> where(id: ^listing.id)
      |> lock("FOR UPDATE")

    multi =
      Multi.new()
      |> Multi.one(:prev_listing, prev_query)
      |> Multi.update(:listing, changeset)
      |> Multi.merge(fn %{prev_listing: prev_listing, listing: listing} ->
        price_unchanged? =
          prev_listing.price_gold == listing.price_gold &&
            prev_listing.price_golden_keys == listing.price_golden_keys

        if !price_unchanged? do
          update_listing_active_offers_multi(listing, :declined_listing_changed)
        else
          Multi.new()
        end
      end)

    case Repo.transaction(multi) do
      {:ok, %{listing: listing}} ->
        broadcast(
          [
            :market,
            market: listing.user_game_item.user,
            listing: listing
          ],
          %ListingUpdated{listing: listing}
        )

        {:ok, listing}

      {:error, _op, changeset, _changes} ->
        {:error, changeset}
    end
  end

  def delete_listing(listing) do
    changeset = Listing.delete(listing)

    multi =
      Multi.new()
      |> Multi.update(:listing, changeset)
      |> update_listing_active_offers(:declined_listing_deleted)

    case Repo.transaction(multi) do
      {:ok, %{listing: listing}} ->
        broadcast(
          [
            :market,
            market: listing.user_game_item.user,
            listing: listing
          ],
          %ListingDeleted{listing: listing}
        )

        {:ok, listing}

      {:error, _op, changeset, _changes} ->
        {:error, changeset}
    end
  end

  def mark_listing_sold(listing) do
    changeset = Listing.mark_sold(listing)

    multi =
      Multi.new()
      |> Multi.update(:listing, changeset)
      |> update_listing_active_offers(:declined_listing_sold)

    case Repo.transaction(multi) do
      {:ok, %{listing: listing}} ->
        broadcast(
          [
            :market,
            market: listing.user_game_item.user,
            listing: listing
          ],
          %ListingSold{listing: listing}
        )

        {:ok, listing}

      {:error, _op, changeset, _changes} ->
        {:error, changeset}
    end
  end

  defp update_listing_active_offers(%Multi{} = multi, new_status) do
    offers_query =
      ListingOffer
      |> where([o], o.status in [:active, :accepted_by_seller])
      |> update(set: [status: ^new_status])

    Multi.update_all(
      multi,
      :offers,
      fn %{listing: listing} ->
        where(offers_query, listing_id: ^listing.id)
      end,
      []
    )
  end

  defp update_listing_active_offers_multi(%Listing{} = listing, new_status) do
    offers_query =
      ListingOffer
      |> where(listing_id: ^listing.id)
      |> where(status: :active)
      |> update(set: [status: ^new_status])

    Multi.update_all(
      Multi.new(),
      :offers,
      offers_query,
      []
    )
  end

  ## Offers

  defp offer_with_item_query() do
    from(o in ListingOffer, as: :offer)
    |> join(:inner, [o], l in assoc(o, :listing), as: :listing)
    |> join(:inner, [o, l], i in assoc(l, :user_game_item), as: :item)
    |> preload(
      [listing: l],
      [
        :user,
        listing: {l, user_game_item: ^{Inventory.user_item_preload_query(), [:user]}}
      ]
    )
  end

  defp group_strings(nil), do: nil

  defp group_strings(%ListingOffer{} = offer) do
    %{
      offer
      | listing: %{
          offer.listing
          | user_game_item: Inventory.group_strings(offer.listing.user_game_item)
        }
    }
  end

  defp preload_item_with_strings(offer) do
    offer
    |> Repo.preload([
      :user,
      listing: [user_game_item: {Inventory.user_item_preload_query(), [:user]}]
    ])
    |> group_strings()
  end

  def list_incoming_offers(%Scope{} = scope, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)
    statuses = Keyword.get(opts, :statuses, [])

    statuses =
      if Enum.empty?(statuses) do
        true
      else
        dynamic([offer: o], o.status in ^statuses)
      end

    offer_with_item_query()
    |> where(^statuses)
    |> join(:inner, [item: i], u in assoc(i, :user), on: u.id == ^scope.current_user_id)
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
    |> Enum.map(&group_strings/1)
  end

  def list_sent_offers(%Scope{} = scope, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)
    statuses = Keyword.get(opts, :statuses, [])

    statuses =
      if Enum.empty?(statuses) do
        true
      else
        dynamic([offer: o], o.status in ^statuses)
      end

    offer_with_item_query()
    |> where(^statuses)
    |> where(user_id: ^scope.current_user_id)
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
    |> Enum.map(&group_strings/1)
  end

  def find_listing_offer(%User{} = seller_or_buyer, offer_id) do
    query =
      offer_with_item_query()
      |> where(id: ^offer_id)
      |> where(
        [offer: o, item: i],
        o.user_id == ^seller_or_buyer.id or i.user_id == ^seller_or_buyer.id
      )

    with {:ok, offer} <- Repo.find(query) do
      {:ok, group_strings(offer)}
    end
  end

  # offer (created | updated | cancelled | expired) ->
  #   offer creator {:market, user_id}
  #   item owner {:market, user_id}

  # TODO own item
  def create_listing_offer(user, listing, attrs) do
    changeset =
      %ListingOffer{user_id: user.id, listing_id: listing.id}
      |> ListingOffer.changeset(attrs)

    case Repo.insert(changeset) do
      {:ok, offer} ->
        broadcast(
          [
            market: user,
            market: listing.user_game_item.user
          ],
          %OfferCreated{offer: preload_item_with_strings(offer)}
        )

        {:ok, offer}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def create_offer(scope, listing_id, attrs, opts \\ []) do
    listing_query =
      active_listing_query()
      |> where(id: ^listing_id)
      |> lock("FOR UPDATE")

    changeset =
      %ListingOffer{user_id: scope.current_user_id, listing_id: listing_id}
      |> ListingOffer.changeset(attrs)

    multi =
      Multi.new()
      |> Multi.one(:listing, listing_query)
      |> Multi.run(:offer, fn
        _repo, %{listing: nil} ->
          {:error, :not_found}

        repo, %{listing: listing} ->
          buyout? = Keyword.get(opts, :buyout?, false)

          with :ok <- maybe_validate_buyout_offer(listing, changeset, opts),
               true <- buyout? || listing.open_for_offers,
               :active <- listing.status do
            repo.insert(changeset)
          else
            false ->
              {:error, :offers_closed}

            {:error, reason} ->
              {:error, reason}

            _ ->
              {:error, :inactive_listing}
          end
      end)

    case Repo.transaction(multi) do
      {:ok, %{offer: offer}} ->
        offer = preload_item_with_strings(offer)

        broadcast(
          [
            market: scope.current_user,
            market: offer.listing.user_game_item.user
          ],
          %OfferCreated{offer: offer}
        )

        {:ok, offer}

      {:error, _op, reason, _changes} ->
        {:error, reason}
    end
  end

  defp maybe_validate_buyout_offer(listing, changeset, buyout?: true) do
    if buyout_offer?(listing, changeset) do
      :ok
    else
      {:error, :price_changed}
    end
  end

  defp maybe_validate_buyout_offer(_, _, _), do: :ok

  defp buyout_offer?(listing, changeset) do
    gold_offer = Ecto.Changeset.get_change(changeset, :offer_gold_amount)
    golden_keys_offer = Ecto.Changeset.get_change(changeset, :offer_golden_keys_amount)

    listing.price_gold == gold_offer &&
      listing.price_golden_keys == golden_keys_offer
  end

  def build_offer(%Scope{} = scope, %Listing{} = listing) do
    %ListingOffer{user_id: scope.current_user_id, listing_id: listing.id}
  end

  def change_offer(%ListingOffer{} = offer, attrs \\ %{}) do
    ListingOffer.changeset(offer, attrs)
  end

  def accept_offer(%Scope{} = scope, offer_id) do
    offer_query =
      ListingOffer
      |> where(id: ^offer_id)
      |> join(:inner, [lo], l in assoc(lo, :listing), as: :listing)
      |> join(:inner, [lo, l], s in assoc(l, :seller), as: :seller)
      |> where([seller: s], s.id == ^scope.current_user_id)
      |> preload(:user)
      |> lock("FOR UPDATE")

    multi =
      Multi.new()
      |> Multi.one(:offer, offer_query)
      |> Multi.run(:accept_offer, fn _repo, %{offer: offer} ->
        case offer.status do
          :active ->
            offer
            |> ListingOffer.change_status(:accepted_by_seller)
            |> Repo.update()

          status ->
            {:error, {:unacceptable_status, status}}
        end
      end)

    case Repo.transaction(multi) do
      {:ok, %{accept_offer: accepted_offer}} ->
        accepted_offer = preload_item_with_strings(accepted_offer)

        broadcast(
          [
            market: accepted_offer.user,
            market: scope.current_user
          ],
          %OfferAccepted{offer: accepted_offer}
        )

        {:ok, accepted_offer}

      {:error, _op, reason, _changes} ->
        {:error, reason}
    end
  end

  def decline_offer(scope, offer_id) do
    offer_query =
      ListingOffer
      |> where(id: ^offer_id)
      |> join(:inner, [lo], l in assoc(lo, :listing), as: :listing)
      |> join(:inner, [lo, l], s in assoc(l, :seller), as: :seller)
      |> where([seller: s], s.id == ^scope.current_user_id)
      |> preload(:user)

    offer = Repo.one!(offer_query)

    if offer.status in [:active, :accepted_by_seller] do
      changeset = ListingOffer.change_status(offer, :declined_by_seller)

      with {:ok, offer} <- Repo.update(changeset) do
        offer = preload_item_with_strings(offer)

        broadcast(
          [
            market: offer.user,
            market: scope.current_user
          ],
          %OfferDeclined{offer: offer}
        )

        {:ok, offer}
      end
    else
      {:ok, offer}
    end
  end

  defp broadcast(topics, event) do
    for topic <- topics do
      Phoenix.PubSub.broadcast(
        @pubsub,
        topic(topic),
        {__MODULE__, event}
      )
    end
  end

  # test
  defp apply_listing_filters(query, filters) do
    {simple_filters, mods} =
      Enum.split_with(filters, fn filter ->
        elem(filter, 0) in [:price, :item_base, :rarities]
      end)

    {props, mods} =
      Enum.split_with(mods, fn filter ->
        elem(filter, 0) == :property
      end)

    query
    |> join(:inner, [listing: l], i in assoc(l, :user_game_item), as: :item)
    |> join(:inner, [item: i], b in assoc(i, :item_base), as: :item_base)
    |> join(:inner, [item_base: b], r in assoc(b, :item_rarity), as: :rarity)
    |> listing_filters(simple_filters)
    |> item_mods_filters(mods)
    |> item_base_props_filter(props)
  end

  def listing_filters(query, filters) do
    Enum.reduce(filters, query, fn filter, query ->
      where(query, ^apply_filter(filter))
    end)
  end

  def item_base_props_filter(query, []), do: query

  def item_base_props_filter(query, filters) do
    props_query =
      from(Dakka.Game.ItemBaseMod, as: :item_base_mod)
      |> join(:inner, [bm], m in assoc(bm, :item_mod), as: :item_mod)
      |> join(:inner, [bm], v in assoc(bm, :item_mod_values), as: :item_mod_values)

    props_query =
      Enum.reduce(filters, props_query, fn filter, query ->
        or_where(query, ^apply_filter(filter))
      end)

    props_query =
      props_query
      |> group_by([bm], bm.item_base_id)
      |> having([bm], count(bm.id) == ^length(filters))
      |> select([bm], %{item_base_id: bm.item_base_id, count: count(bm.id)})

    join(query, :inner, [item_base: ib], f in subquery(props_query), on: ib.id == f.item_base_id)
  end

  defp item_mods_filters(query, []), do: query

  defp item_mods_filters(query, filters) do
    mods_query =
      from(um in Dakka.Inventory.UserGameItemMod, as: :user_mod)
      |> join(:inner, [um], m in assoc(um, :item_mod), as: :mod)
      |> join(:left, [mod: m], v in assoc(m, :values), as: :mod_values)

    mods_query =
      Enum.reduce(filters, mods_query, fn filter, query ->
        or_where(query, ^apply_filter(filter))
      end)

    mods_query =
      mods_query
      |> group_by([um], um.user_game_item_id)
      |> having([um], count(um.id) == ^length(filters))
      |> select([um], %{item_id: um.user_game_item_id})

    join(query, :inner, [item: i], f in subquery(mods_query), on: i.id == f.item_id)
  end

  defp apply_filter({:price, :gold, op, value}) do
    comp(:listing, :price_gold, op, value)
  end

  defp apply_filter({:price, :golden_keys, op, value}) do
    comp(:listing, :price_golden_keys, op, value)
  end

  defp apply_filter({:price, :open_for_offers, _, value}) do
    comp(:listing, :open_for_offers, :eq, value)
  end

  defp apply_filter({:item_base, item_base}) do
    comp(:item_base, :slug, :eq, item_base)
  end

  defp apply_filter({:rarities, rarities}) do
    dynamic([rarity: rarity], rarity.slug in ^rarities)
  end

  defp apply_filter({:property, slug, :in, value}) do
    dynamic(
      [user_mod: um, mod: m, mod_values: values],
      m.slug == ^slug and
        um.mod_type == ^:property and
        values.slug in ^[value]
    )
  end

  defp apply_filter({mod_type, slug, op, value}) when mod_type in [:implicit, :explicit] do
    dynamic = dynamic([user_mod: um, mod: m], m.slug == ^slug and um.mod_type == ^mod_type)

    if value do
      dynamic([], ^dynamic and ^comp(:user_mod, :value, op, value))
    else
      dynamic
    end
  end

  defp apply_filter({:property, slug, _op, value}) do
    dynamic =
      dynamic(
        [item_base_mod: ibm, item_mod: im, item_mod_values: imv],
        ibm.mod_type == :property and im.slug == ^slug
      )

    if value do
      dynamic([item_mod_values: imv], ^dynamic and imv.slug == ^value)
    else
      dynamic
    end
  end

  defp comp(named_binding \\ nil, field, op, value)

  defp comp(named_binding, field, :lt, value) do
    if named_binding do
      dynamic([{^named_binding, l}], field(l, ^field) < ^value)
    else
      dynamic([q], field(q, ^field) < ^value)
    end
  end

  defp comp(named_binding, field, :lt_or_eq, value) do
    if named_binding do
      dynamic([{^named_binding, l}], field(l, ^field) <= ^value)
    else
      dynamic([q], field(q, ^field) <= ^value)
    end
  end

  defp comp(named_binding, field, :gt, value) do
    if named_binding do
      dynamic([{^named_binding, l}], field(l, ^field) > ^value)
    else
      dynamic([q], field(q, ^field) > ^value)
    end
  end

  defp comp(named_binding, field, :gt_or_eq, value) do
    if named_binding do
      dynamic([{^named_binding, l}], field(l, ^field) >= ^value)
    else
      dynamic([q], field(q, ^field) >= ^value)
    end
  end

  defp comp(named_binding, field, :eq, value) do
    if named_binding do
      dynamic([{^named_binding, l}], field(l, ^field) == ^value)
    else
      dynamic([q], field(q, ^field) == ^value)
    end
  end
end