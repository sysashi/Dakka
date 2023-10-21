defmodule Dakka.Market.Events do
  @moduledoc """
  Market events
  """

  defmodule ListingCreated do
    defstruct listing: nil
  end

  defmodule ListingUpdated do
    defstruct listing: nil
  end

  defmodule ListingSold do
    defstruct listing: nil
  end

  defmodule ListingDeleted do
    defstruct listing: nil
  end

  defmodule ListingExpired do
    defstruct listing: nil
  end

  defmodule OfferCreated do
    defstruct offer: nil
  end

  defmodule OfferCancelled do
    defstruct offer: nil
  end

  defmodule OfferAccepted do
    defstruct offer: nil
  end

  defmodule OfferDeclined do
    defstruct offer: nil, reason: nil
  end

  defmodule TradeMessage do
    defstruct message: nil
  end
end
