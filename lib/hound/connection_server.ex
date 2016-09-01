defmodule Hound.ConnectionServer do
  @moduledoc false

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

    IO.inspect "I AM IN THE CONNECTION SERVER AND SETTING DRIVER_INFO TO"
    IO.inspect driver_info
    configs = %{
      :host => options[:app_host] || Application.get_env(:hound, :app_host, "http://localhost"),
      :port => options[:app_port] || Application.get_env(:hound, :app_port, 4001)
    }

    state = %{sessions: [], driver_info: driver_info, configs: configs}

    IO.inspect "AND THE STATE WILL BE"
    IO.inspect state
    Agent.start_link(fn -> state end, name: __MODULE__)
  end

  def driver_info do
    {:ok, Agent.get(__MODULE__, &(&1.driver_info), 60000)}
  end

  def configs do
    {:ok, Agent.get(__MODULE__, &(&1.configs), 60000)}
  end
end
