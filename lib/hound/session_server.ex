defmodule Hound.SessionServer do
  @moduledoc false

  use GenServer
  @name __MODULE__

  def start_link do
    GenServer.start_link(__MODULE__, %{}, name: @name)
  end


  def session_for_pid(pid, opts) do
    current_session_id(pid) ||
      change_current_session_for_pid(pid, :default, opts)
  end


  def current_session_id(pid) do
    case :ets.lookup(@name, pid) do
      [{^pid, _ref, session_id, _all_sessions, _}] -> session_id
      [] -> nil
    end
  end

  def current_session_name(pid) do
    case :ets.lookup(@name, pid) do
      [{^pid, _ref, session_id, all_sessions, _}] ->
        Enum.find_value all_sessions, fn
          {name, id} when id == session_id -> name
          _ -> nil
        end
      [] -> nil
    end
  end


  def change_current_session_for_pid(pid, session_name, opts) do
    GenServer.call(@name, {:change_session, pid, session_name, opts}, 60000)
  end


  def all_sessions_for_pid(pid) do
    case :ets.lookup(@name, pid) do
      [{^pid, _ref, _session_id, all_sessions, _}] -> all_sessions
      [] -> %{}
    end
  end

  def driver_info_for_pid(pid) do
    case :ets.lookup(@name, pid) do
      [{^pid, _ref, session_id, _, driver_info}] -> driver_info[session_id]
      [] -> nil
    end
  end

  def destroy_sessions_for_pid(pid) do
    GenServer.call(@name, {:destroy_sessions, pid}, 60000)
  end

  def destroy_sessions_for_pid(pid, driver_info) do
    GenServer.call(@name, {:destroy_sessions, pid, driver_info}, 60000)
  end
  ## Callbacks

  def init(state) do
    :ets.new(@name, [:set, :named_table, :protected, read_concurrency: true])
    {:ok, state}
  end


  def handle_call({:change_session, pid, session_name, opts}, _from, state) do
    driver_info = if opts[:driver_info] do
      opts[:driver_info]
    else
      {:ok, driver_info} = Hound.driver_info
      driver_info
    end

    {ref, sessions, driver_infos} =
      case :ets.lookup(@name, pid) do
        [{^pid, ref, _session_id, sessions, driver_infos}] ->
          {ref, sessions, driver_infos}
        [] ->
          {Process.monitor(pid), %{}, %{}}
      end

    {session_id, sessions} =
      case Map.fetch(sessions, session_name) do
        {:ok, session_id} ->
          {session_id, sessions}
        :error ->
          {:ok, session_id} = Hound.Session.create_session(driver_info[:browser], opts)
          {session_id, Map.put(sessions, session_name, session_id)}
      end

    {session_id, driver_infos} =
      case Map.fetch(driver_infos, driver_info) do
        {:ok, session_id} ->
          {session_id, driver_infos}
        :error ->
          {:ok, session_id} = Hound.Session.create_session(driver_info[:browser], opts)
          {session_id, Map.put(driver_infos, session_id, driver_info)}
      end
    :ets.insert(@name, {pid, ref, session_id, sessions, driver_infos})
    {:reply, session_id, Map.put(state, ref, pid)}
  end

  def handle_call({:destroy_sessions, pid}, _from, state) do
    destroy_sessions(pid)
    {:reply, :ok, state}
  end

  def handle_call({:destroy_sessions, pid, driver_info}, _from, state) do
    destroy_sessions(pid, driver_info)
    {:reply, :ok, state}
  end

  def handle_info({:DOWN, ref, _, _, _}, state) do
    if pid = state[ref] do
      destroy_sessions(pid)
    end
    {:noreply, state}
  end

  defp destroy_sessions(pid) do
    sessions = all_sessions_for_pid(pid)
    :ets.delete(@name, pid)
    Enum.each sessions, fn({_session_name, session_id})->
      Hound.Session.destroy_session(session_id)
    end
  end

  defp destroy_sessions(pid, driver_info) do
    sessions = all_sessions_for_pid(pid)
    :ets.delete(@name, pid)
    Enum.each sessions, fn({_session_name, session_id})->
      Hound.Session.destroy_session(session_id, driver_info)
    end
  end
end
