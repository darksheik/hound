defmodule Hound.ConnectionServer do
  @moduledoc false

  use GenServer

  def start_link(options \\ []) do
    driver = options[:driver] || Application.get_env(:hound, :driver, "selenium")

    {default_port, default_path_prefix, default_browser} = case driver do
      "chrome_driver" ->
        {9515, nil, "chrome"}
      "phantomjs" ->
        {8910, nil, "phantomjs"}
      _ -> # assume selenium
        {4444, "wd/hub/", "firefox"}
    end


    browser = options[:browser] || Application.get_env(:hound, :browser, default_browser)
    host = options[:host] || Application.get_env(:hound, :host, "http://localhost")
    port = options[:port] || Application.get_env(:hound, :port, default_port)
    path_prefix = options[:path_prefix] || Application.get_env(:hound, :path_prefix, default_path_prefix)


    driver_info = %{
      :driver => driver,
      :browser => browser,
      :host => host,
      :port => port,
      :path_prefix => path_prefix
    }

    configs = %{
      :host => options[:app_host] || Application.get_env(:hound, :app_host, "http://localhost"),
      :port => options[:app_port] || Application.get_env(:hound, :app_port, 4001)
    }

    state = %{sessions: %{}, driver_info: driver_info, configs: configs}
    :gen_server.start_link({:local, __MODULE__}, __MODULE__, state, [])
  end


  def init(state) do
    {:ok, state}
  end


  def handle_call({:add_session, pid, session, value}, _from, state) do
    session_info = state[:sessions]
       |> Map.put(session, value)

    new_sessions = Map.merge(state[:sessions], session_info)
    new_state = Map.merge(state, %{sessions: new_sessions})

    {:reply, new_state[session_info], new_state}
  end

  def handle_call({:delete_session, pid, session}, _from, state) do
    session_info = state[:sessions]
       |> Map.delete(session)

    new_state = Map.put(state, :sessions, session_info)

    {:reply, new_state[session_info], new_state}
  end

  def handle_call(state_key, _from, state) do
    {:reply, state[state_key], state}
  end

  def driver_info do
    driver_info = :gen_server.call __MODULE__, :driver_info, 60000
    {:ok, driver_info}
  end

  def configs do
    configs = :gen_server.call __MODULE__, :configs, 60000
    {:ok, configs}
  end

end
