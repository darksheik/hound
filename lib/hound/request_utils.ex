defmodule Hound.RequestUtils do
  @moduledoc false

  @retry_time Application.get_env(:hound, :retry_time, 250)

  @http_options Application.get_env(:hound, :http, [])


  def make_req(type, path, params \\ %{}, options \\ %{}, retries \\ 0) do
    if retries > 0 do
      try do
        send_req(type, path, params, options)
      catch
        _ ->
          :timer.sleep(@retry_time)
          make_req(type, path, params, options, retries - 1)
      rescue
        _ ->
          :timer.sleep(@retry_time)
          make_req(type, path, params, options, retries - 1)
      end
    else
      send_req(type, path, params, options)
    end
  end


  defp send_req(type, path, params, options) do
    url = get_url(path, options)

    if params != %{} && type == :post do
      headers = [{"Content-Type", "text/json"}]
      if options[:json_encode] != false do
        body = Poison.encode! params
      else
        body = params
      end
    else
      headers = []
      body = ""
    end

    case type do
      :get ->
        {status, resp} = HTTPoison.get(url, headers, @http_options)
      :post ->
        {status, resp} = HTTPoison.post(url, body, headers, @http_options)
      :delete ->
        {status, resp} = HTTPoison.delete(url, headers, @http_options)
    end

    {:ok, driver_info} = if options[:driver_info] do
      {:ok, options[:driver_info]}
    else
      {:ok, Hound.SessionServer.driver_info(self)}
    end

    case resp do
      %HTTPoison.Error{id: nil, reason: :timeout} ->
        {:error, :timeout}
      _ ->
      case response_parser(driver_info).parse(path, resp.status_code, resp.body) do
        :error ->
          raise """
          Webdriver call status code #{resp.status_code} for #{type} request #{url}.
          Check if webdriver server is running. Make sure it supports the feature being requested.
          """
        response -> response
      end
    end
  end


  defp response_parser(driver_info) do
    case driver_info.driver do
      "selenium" ->
        Hound.ResponseParsers.Selenium
      "chrome_driver" ->
        Hound.ResponseParsers.ChromeDriver
      "phantomjs" ->
        Hound.ResponseParsers.PhantomJs
      other_driver ->
        raise "No response parser found for #{other_driver}"
    end
  end


  def decode_content(content) do
    if content != [] do
      Poison.decode!(content)
    else
      Map.new
    end
  end


  defp get_url(path, options) do
    {:ok, driver_info} = if options[:driver_info] do
      {:ok, options[:driver_info]}
    else
      {:ok, Hound.SessionServer.driver_info(self)}
    end

    if options[:custom_selenium_host] do
      driver_info = Map.put(driver_info, :host, options[:custom_selenium_host])
    else
      if (csh = Hound.SessionServer.custom_selenium_host(self)) do
        driver_info = Map.put(driver_info, :host, csh)
      end
    end

    host = driver_info[:host]
    port = driver_info[:port]
    path_prefix = driver_info[:path_prefix]

    "#{host}:#{port}/#{path_prefix}#{path}"
  end
end
