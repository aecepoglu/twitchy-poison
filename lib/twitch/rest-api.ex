defmodule Twitch.REST_API do
  use HTTPoison.Base


  @impl true
  def process_request_url(url) do
    "https://api.twitch.tv/helix/" <> url
    #"http://127.0.0.1:8080/" <> url
  end

  @impl true
  def process_response_body(body) do
    Poison.decode!(body)
  end

  @impl true
  def process_request_body(body) do
    Poison.encode!(body)
  end
end

defmodule Twitch.Request do
  def subscribe(topic, version, condition, transport, headers) do
     body = %{
      "type" => topic,
      "version" => version,
      "condition" => condition,
      "transport" => transport,
    }
    Twitch.REST_API.post("eventsub/subscriptions", body, headers)
  end

  def channels_followers(broadcaster_id, headers, opts \\ []) do
    frst = Keyword.get(opts, :first, 100)
    params = if Keyword.has_key?(opts, :after) do
      [after: Keyword.fetch!(opts, :after)]
    else
      []
    end ++ [broadcaster_id: broadcaster_id, first: frst]
    options = [params: params]
    {:ok, %{body: body}} = Twitch.REST_API.get("channels/followers", headers, options)
    case body["pagination"] do
      %{"cursor" => cur} -> body["data"] ++ channels_followers(broadcaster_id, headers, after: cur)
      %{} -> body["data"]
    end
  end
end
