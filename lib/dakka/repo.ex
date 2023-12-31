defmodule Dakka.Repo do
  use Ecto.Repo,
    otp_app: :dakka,
    adapter: Ecto.Adapters.Postgres

  def find(query) do
    case all(query) do
      [] -> {:error, :not_found}
      [record] -> {:ok, record}
      _ -> raise "Multiple records found, #{inspect(query)}"
    end
  end
end
