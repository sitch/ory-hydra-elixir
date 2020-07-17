defmodule ORY.Hydra.Helpers.Body do
  @spec encode!(ORY.Hydra.Operation.t(), ORY.Hydra.Config.t()) :: String.t() | no_return
  def encode!(%{method: :get}, _config) do
    ""
  end

  def encode!(operation, config) do
    operation.params
    |> Map.drop(operation.params_in_query)
    |> config.json_codec.encode!()
  end

  def form_encode!(operation, config) do
    opts = [:encode, &URI.encode_query/1]

    # note ?
    :NOT_IMPLEMENTED
  end
end
