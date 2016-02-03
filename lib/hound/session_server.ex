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

  # All of these now pass the call down to the correct gen_server per host
  def session_for_pid(pid, additional_capabilities, custom_selenium_host) do
    host = String.to_atom(custom_selenium_host)
    gen_server_pid = get_gen_server_pid(host)
    :gen_server.call host, {:find_or_create_session, pid, gen_server_pid, additional_capabilities, custom_selenium_host}, 30000
  end


  def current_session_id(pid) do
    host = get_server_host(pid)
    gen_server_pid = get_gen_server_pid(host)
    :gen_server.call host, {:current_session, pid, gen_server_pid}, 30000
  end

  def custom_selenium_host(pid) do
    host = get_server_host(pid)
    gen_server_pid = get_gen_server_pid(host)
    :gen_server.call host, {:custom_selenium_host, pid, gen_server_pid}, 30000
  end

  def change_current_session_for_pid(pid, gen_server_pid, session_name, additional_capabilities, custom_selenium_host) do
    host = get_server_host(pid)
    gen_server_pid = get_gen_server_pid(host)
    :gen_server.call host, {:change_session, pid, gen_server_pid, session_name, additional_capabilities, custom_selenium_host}, 30000
  end

  def all_sessions_for_pid(pid) do
    host = get_server_host(pid)
    gen_server_pid = get_gen_server_pid(host)
    :gen_server.call host, {:all_sessions, pid, gen_server_pid}, 30000
  end

  def destroy_sessions_for_pid(pid) do
    host = get_server_host(pid)
    gen_server_pid = get_gen_server_pid(host)
    :gen_server.call host, {:destroy_sessions, pid, gen_server_pid}, 30000
  end

  def get_gen_server_pid(custom_selenium_host) do
    case Supervisor.start_child(@name, [custom_selenium_host]) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
  end

  def get_server_host(pid) do
    sessions = :gen_server.call Hound.ConnectionServer, :sessions
    sessions[pid]
  end
end
