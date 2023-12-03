defmodule OAuthServer do
  @redirport 3456

  def navigate() do
    roles = ["moderator:read:followers", "chat:read", "chat:edit"]
    clientid = "er74mamcsw4il4ctkzvzrznnj9t2w1"
    url = %URI{
      scheme: "https",
      host: "id.twitch.tv",
      path: "/oauth2/authorize",
    }
    |> URI.append_query("response_type=token")
    |> URI.append_query("client_id=#{clientid}")
    |> URI.append_query("redirect_uri=http://localhost:#{@redirport}")
    |> URI.append_query("scope=" <> Enum.join(roles, "+"))
    |> URI.to_string()
    spawn(fn -> System.cmd("firefox", [url]) end)
  end

  def listen() do
    opts = [:binary,
            packet: :line,
            active: false,
            reuseaddr: true
            ]
    {:ok, sock} = :gen_tcp.listen(@redirport, opts)
    {:ok, client} = :gen_tcp.accept(sock)
    {:ok, _first} = :gen_tcp.recv(client, 0)
    :ok = send_redir_response(client)
    :ok = :gen_tcp.close(client)
    {:ok, client} = :gen_tcp.accept(sock)
    {:ok, auth_token} = recv_auth_token(client)
    send_html_response(client, "<script>window.close()</script>I am done. You can close the tab.")
    :ok = :gen_tcp.close(client)
    :ok = :gen_tcp.close(sock)
    {:ok, auth_token}
  end

  defp send_html_response(client, body) do
    :gen_tcp.send(client, """
HTTP/1.1 200 OK
Date: #{Time.utc_now()}
Content-Type: text/html
Content-Length: #{String.length(body)}

#{body}
""")
  end

  defp send_redir_response(client) do
    body = """
<script>if(location.hash.includes('#')){
window.location.href=location.hash.replace('#','?')}</script> Redirecting...
"""
    send_html_response(client, body)
  end

  defp recv_auth_token(client) do
    {:ok, first} = :gen_tcp.recv(client, 0)
    ["GET", path | _] = String.split(first)
    {:ok, %URI{}=uri} = URI.new(path)
    case URI.decode_query(uri.query) do
      %{"access_token" => x} -> {:ok, x}
      _                      -> {:error, "unable to find auth token"}
    end
  end

  def whatever() do
    navigate()
    listen()
  end
end
