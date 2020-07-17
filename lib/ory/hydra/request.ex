defmodule ORY.Hydra.Request do
  alias ORY.Hydra.{Helpers, Response}

  @type t ::
          %__MODULE__{
            attempt: integer,
            body: binary,
            headers: ORY.Hydra.http_headers_t(),
            method: ORY.Hydra.http_method_t(),
            result: any,
            url: String.t()
          }

  defstruct attempt: 0,
            body: nil,
            headers: nil,
            method: nil,
            result: nil,
            url: nil

  defp form_encode(operation) do
    operation.params
  end

  @spec send(ORY.Hydra.Operation.t(), ORY.Hydra.Config.t()) :: ORY.Hydra.response_t()
  def send(%{method: method} = operation, config) do
    url = Helpers.URL.to_string(operation, config)

    {body, headers} =
      case method do
        method when method in [:delete, :get, :post, :put] ->
          {Helpers.Body.encode!(operation, config), [{"content-type", "application/json"}]}

        :form ->
          {form_encode(operation), [{"content-type", "application/x-www-form-urlencoded"}]}
      end

    request = %__MODULE__{}
    request = Map.put(request, :url, url)
    request = Map.put(request, :body, body)
    request = Map.put(request, :method, method)
    request = Map.put(request, :headers, headers)

    dispatch(request, config)
  end

  defp dispatch(request, config) do
    http_client = config.http_client

    result =
      http_client.request(
        request.method,
        request.url,
        request.headers,
        request.body,
        config.http_client_opts
      )

    request = Map.put(request, :attempt, request.attempt + 1)
    request = Map.put(request, :result, result)

    request
    |> retry(config)
    |> finish(config)
  end

  defp retry(request, config) do
    max_attempts = Keyword.get(config.retry_opts, :max_attempts, 3)

    if config.retry && max_attempts > request.attempt do
      case request.result do
        {:ok, %{status_code: status_code}} when status_code >= 500 ->
          dispatch(request, config)

        {:error, _reason} ->
          dispatch(request, config)

        _otherwise ->
          request
      end
    else
      request
    end
  end

  defp finish(request, config) do
    case request.result do
      {:ok, %{status_code: status_code} = response} when status_code >= 400 ->
        {:error, Response.new(response, config)}

      {:ok, %{status_code: status_code} = response} when status_code >= 200 ->
        {:ok, Response.new(response, config)}

      otherwise ->
        otherwise
    end
  end
end
