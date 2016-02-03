defmodule Hound.SessionHostServer do
  @moduledoc false

  use GenServer

  def start_link(host) do
    state = HashDict.new
    :gen_server.start_link({:local, host}, __MODULE__, state, name: host)
  end


  def init(state) do
    {:ok, state}
  end


  def handle_call({:find_or_create_session, pid, gen_server_pid, additional_capabilities, custom_selenium_host}, _from, state) do
    {:ok, driver_info} = Hound.driver_info

    case state[gen_server_pid][:current] do
      nil ->
        {:ok, session_id} = Hound.Session.create_session(driver_info[:browser], additional_capabilities, custom_selenium_host)

        all_sessions = HashDict.new
          |> HashDict.put :default, session_id

        session_info = HashDict.new
          |> HashDict.put(:current, session_id)
          |> HashDict.put(:all_sessions, all_sessions)
          |> HashDict.put(:custom_selenium_host, custom_selenium_host)

        :gen_server.call Hound.ConnectionServer, {:add_session, self, pid, String.to_atom(custom_selenium_host)}

        state_upgrade = HashDict.new |> HashDict.put(pid, session_info)
        new_state = HashDict.merge(state, state_upgrade)
        {:reply, session_id, new_state}
      session_id ->
        {:reply, session_id, state}
    end
  end


  def handle_call({:current_session, pid, gen_server_pid}, _from, state) do
    if HashDict.has_key?(state, pid) do
      {:reply, state[pid][:current], state}
    else
      {:reply, nil, state}
    end
  end

  def handle_call({:custom_selenium_host, pid, gen_server_pid}, _from, state) do
    if HashDict.has_key?(state, pid) do
      {:reply, state[pid][:custom_selenium_host], state}
    else
      {:reply, nil, state}
    end
  end

  def handle_call({:change_session, pid, gen_server_pid, session_name, additional_capabilities, custom_selenium_host}, _from, state) do
    {:ok, driver_info} = Hound.driver_info

    pid_info = state[pid]
    session_id = pid_info[:all_sessions][session_name]

    if session_id do
      pid_info_update = HashDict.put(pid_info, :current, session_id)
    else
      {:ok, session_id} = Hound.Session.create_session(driver_info[:browser], additional_capabilities, custom_selenium_host)

      all_sessions_update = HashDict.put(pid_info[:all_sessions], session_name, session_id)
      pid_info_update = pid_info
        |> HashDict.put(:current, session_id)
        |> HashDict.put(:all_sessions, all_sessions_update)
        |> HashDict.put(:custom_selenium_host, custom_selenium_host)
    end

    new_state = HashDict.put(state, pid, pid_info_update)
    IO.puts "NEW STATE ***************"
    IO.inspect new_state
    {:reply, session_id, new_state}
  end


  def handle_call({:all_sessions, pid, gen_server_pid}, _from, state) do
    if HashDict.has_key?(state, pid) do
      {:reply, state[pid][:all_sessions], state}
    else
      {:reply, [], state}
    end
  end


  def handle_call({:destroy_sessions, pid, gen_server_pid}, _from, state) do
    if HashDict.has_key?(state, pid) do
      sessions = state[pid][:all_sessions]
      Enum.each sessions, fn({_session_name, session_id})->
        Hound.Session.destroy_session(session_id, state[pid][:custom_selenium_host])
      end
      state = HashDict.delete(state, pid)
    end
    {:reply, :ok, state}
  end
end
