defmodule Hound.SessionServer do
  @moduledoc false

  use Supervisor
  @name Hound.SessionServer

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: @name)
  end


  def init(:ok) do
    children = [
      worker(Hound.SessionHostServer, [])
    ]
    supervise(children, strategy: :simple_one_for_one)
  end

  # All of these now pass the call down to the correct gen_server per host
  def session_for_pid(pid, additional_capabilities, custom_selenium_host) do
    name = String.to_atom(inspect pid)
    gen_server_pid = get_gen_server_pid(name)
    :gen_server.call name, {:find_or_create_session, pid, gen_server_pid, additional_capabilities, custom_selenium_host}, 30000
  end

  def current_session_id(pid) do
    name = String.to_atom(inspect pid)
    gen_server_pid = get_gen_server_pid(name)
    :gen_server.call name, {:current_session, pid, gen_server_pid}, 30000
  end

  def custom_selenium_host(pid) do
    name = String.to_atom(inspect pid)
    gen_server_pid = get_gen_server_pid(name)
    :gen_server.call name, {:custom_selenium_host, pid, gen_server_pid}, 30000
  end

  def change_current_session_for_pid(pid, gen_server_pid, session_name, additional_capabilities, custom_selenium_host) do
    name = String.to_atom(inspect pid)
    gen_server_pid = get_gen_server_pid(name)
    :gen_server.call name, {:change_session, pid, gen_server_pid, session_name, additional_capabilities, custom_selenium_host}, 30000
  end

  def all_sessions_for_pid(pid) do
    name = String.to_atom(inspect pid)
    gen_server_pid = get_gen_server_pid(name)
    :gen_server.call name, {:all_sessions, pid, gen_server_pid}, 30000
  end

  def destroy_sessions_for_pid(pid) do
    name = String.to_atom(inspect pid)
    gen_server_pid = get_gen_server_pid(name)
    :gen_server.call name, {:destroy_sessions, pid, gen_server_pid}, 30000
    Supervisor.terminate_child(@name, gen_server_pid)
  end

  def get_gen_server_pid(name) do
    case Supervisor.start_child(@name, [name]) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
  end

end
