# This file is a part of Exopticon, a free video surveillance tool. Visit
# https://exopticon.org for more information.
#
# Copyright (C) 2018 David Matthew Mattli
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

defmodule ExopticonWeb.PlaybackChannel do
  @moduledoc """
  Provides channel implementation for video file playback
  """
  use ExopticonWeb, :channel

  alias Exopticon.PlaybackSupervisor
  alias Exopticon.Repo

  intercept(["jpg"])

  def join("playback:lobby", payload, socket) do
    if authorized?(payload) do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  def join("playback:" <> _params, _payload, socket) do
    {:ok, socket}
  end

  def handle_in("start_player", %{"topic" => "playback:" <> params}, socket) do
    [_, file_id, offset] = params |> String.split(",") |> Enum.map(&String.to_integer/1)
    file = Repo.get!(Exopticon.Video.File, file_id)
    PlaybackSupervisor.start_playback({"playback:" <> params, file, offset})
    socket = assign(socket, :topic, "playback:" <> params)
    {:noreply, socket}
  end

  def handle_in("kill_player", %{"topic" => topic}, socket) do
    IO.puts("Stopping player: " <> topic)
    PlaybackSupervisor.stop_playback(topic)
    {:noreply, socket}
  end

  def handle_in("ack", payload, socket) do
    topic = socket.assigns[:topic]
    regs = Registry.lookup(Registry.PlayerRegistry, topic)
    pids = Enum.map(regs, fn {pid, _} -> pid end)
    cur_time = System.monotonic_time(:milliseconds)
    cur_live = socket.assigns[:cur_live]
    max_live = socket.assigns[:max_live]
    old_rtt = socket.assigns[:rtt]

    Enum.each(pids, fn p ->
      GenServer.cast(p, :ack)
    end)

    %{"ts" => ts} = payload
    {ts_int, _} = Integer.parse(ts)

    new_rtt = cur_time - ts_int
    rtt = (new_rtt + old_rtt) / 2

    max_live =
      if new_rtt > 2 * old_rtt do
        Enum.max([div(max_live, 2), 1])
      else
        Enum.min([max_live + 1, 10])
      end

    socket = assign(socket, :max_live, max_live)
    socket = assign(socket, :cur_live, cur_live - 1)
    socket = assign(socket, :rtt, rtt)

    {:noreply, socket}
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (playback:lobby).
  def handle_in("shout", payload, socket) do
    broadcast(socket, "shout", payload)
    {:noreply, socket}
  end

  def handle_out("jpg", params, socket) do
    cur_live = socket.assigns[:cur_live]
    max_live = socket.assigns[:max_live]

    new_cur_live =
      if cur_live < max_live do
        cur_time = System.monotonic_time(:milliseconds)
        params = Map.put(params, :ts, to_string(cur_time))
        push(socket, "jpg", params)
        cur_live + 1
      else
        cur_live
      end

    socket = assign(socket, :cur_live, new_cur_live)
    {:noreply, socket}
  end

  # Add authorization logic here as required.
  defp authorized?(_payload) do
    true
  end
end
