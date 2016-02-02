defmodule Hound.SessionServer do
  @moduledoc false

  use Supervisor
  @name Hound.SessionServer

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: @name)
    #:gen_server.start_link({:local, __MODULE__}, __MODULE__, state, [])
  end


  def init(:ok) do
    children = [
      worker(Hound.SessionHostServer, [])
    ]
    supervise(children, strategy: :simple_one_for_one)
  end

  def handle_call({:current_session, pid}, _from, state) do
    if HashDict.has_key?(state, pid) do
      {:reply, state[pid][:current], state}
    else
      {:reply, nil, state}
    end
  end

  def handle_call({:custom_selenium_host, pid}, _from, state) do
    if HashDict.has_key?(state, pid) do
      {:reply, state[pid][:custom_selenium_host], state}
    else
      {:reply, nil, state}
    end
  end

  def handle_call({:change_session, pid, session_name, additional_capabilities, custom_selenium_host}, _from, state) do
    {:ok, driver_info} = Hound.driver_info

    pid_info = state[pid]
    session_id = pid_info[:all_sessions][session_name]

    if session_id do
      pid_info_update = HashDict.put(pid_info, :current, session_id)
      hosts = HashDict.new
    else
      gen_server_pid = get_gen_server_pid(state[pid][:custom_selenium_host])
      GenServer.call(Hound.SessionHostServer, {:current_session, gen_server_pid}, 30000)

      session_id = GenServer.call(Hound.SessionHostServer, {:create_session, driver_info[:browser], additional_capabilities, custom_selenium_host}, 30000)

      all_sessions_update = HashDict.put(pid_info[:all_sessions], session_name, session_id)
      pid_info_update = pid_info
        |> HashDict.put(:current, session_id)
        |> HashDict.put(:all_sessions, all_sessions_update)
        |> HashDict.put(:custom_selenium_host, custom_selenium_host)

      hosts = HashDict.new
        |> HashDict.put(custom_selenium_host, gen_server_pid)
    end

    state_upgrade = HashDict.new |> HashDict.put(pid, pid_info_update)
      |> HashDict.put(:hosts, hosts)

    new_state = HashDict.merge(state, state_upgrade)

    {:reply, session_id, new_state}
  end


  def handle_call({:all_sessions, pid}, _from, state) do
    if HashDict.has_key?(state, pid) do
      {:reply, state[pid][:all_sessions], state}
    else
      {:reply, [], state}
    end
  end


  def handle_call({:destroy_sessions, pid}, _from, state) do
    if HashDict.has_key?(state, pid) do
      sessions = state[pid][:all_sessions]
      Enum.each sessions, fn({_session_name, session_id})->
        gen_server_pid = get_gen_server_pid(state[pid][:custom_selenium_host])
        GenServer.call(Hound.SessionHostServer, {:destroy_sessions, gen_server_pid}, 30000)
      end
      state = HashDict.delete(state, pid)
    end
    {:reply, :ok, state}
  end


  def session_for_pid(pid, additional_capabilities, custom_selenium_host) do
    gen_server_pid = get_gen_server_pid(custom_selenium_host)
    :gen_server.call String.to_atom(custom_selenium_host), {:find_or_create_session, gen_server_pid, additional_capabilities, custom_selenium_host}, 30000
  end


  def current_session_id(pid) do
    :gen_server.call __MODULE__, {:current_session, pid}, 30000
  end

  def custom_selenium_host(pid) do
    :gen_server.call __MODULE__, {:custom_selenium_host, pid}, 30000
  end


  def change_current_session_for_pid(pid, session_name, additional_capabilities, custom_selenium_host) do
    :gen_server.call __MODULE__, {:change_session, pid, session_name, additional_capabilities, custom_selenium_host}, 30000
  end


  def all_sessions_for_pid(pid) do
    :gen_server.call __MODULE__, {:all_sessions, pid}, 30000
  end


  def destroy_sessions_for_pid(pid) do
    :gen_server.call __MODULE__, {:destroy_sessions, pid}, 30000
  end

  def get_gen_server_pid(custom_selenium_host) do
    case Supervisor.start_child(@name, [custom_selenium_host]) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
  end
end
