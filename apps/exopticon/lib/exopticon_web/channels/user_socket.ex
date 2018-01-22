defmodule ExopticonWeb.UserSocket do
  use Phoenix.Socket

  @max_age 2 * 7 * 24 * 60 * 60

  ## Channels
  channel("camera:*", ExopticonWeb.CameraChannel)
  channel("playback:*", ExopticonWeb.PlaybackChannel)

  ## Transports
  transport(:websocket, Phoenix.Transports.WebSocket, serializer: [
    {ExopticonWeb.Transports.MessagePackSerializer, "~> 2.0.0"}
  ])

  # transport :longpoll, Phoenix.Transports.LongPoll

  # Socket params are passed from the client and can
  # be used to verify and authenticate a user. After
  # verification, you can put default assigns into
  # the socket that will be set for all channels, ie
  #
  #     {:ok, assign(socket, :user_id, verified_user_id)}
  #
  # To deny connection, return `:error`.
  #
  # See `Phoenix.Token` documentation for examples in
  # performing token verification on connect.
  def connect(%{"token" => token}, socket) do
    case Phoenix.Token.verify(socket, "user socket", token, max_age: @max_age) do
      {:ok, user_id} ->
        socket = assign(socket, :user_id, user_id)
        socket = assign(socket, :max_live, 1)
        socket = assign(socket, :cur_live, 0)
        socket = assign(socket, :rtt, 0)
        socket = assign(socket, :watch_camera, %{})
        {:ok, socket}

      {:error, _reason} ->
        :error
    end
  end

  def connect(_params, _socket), do: :error

  # Socket id's are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     ExopticonWeb.Endpoint.broadcast("user_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  def id(socket), do: "users_socket:#{socket.assigns.user_id}"
end
