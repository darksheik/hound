defmodule Hound.RequestUtils do
  @moduledoc false

  @retry_time Application.get_env(:hound, :retry_time, 250)

  @http_options Application.get_env(:hound, :http, [])


  def make_req(type, path, params \\ %{}, options \\ %{}, retries \\ 0)
  def make_req(type, path, params, options, 0) do
    send_req(type, path, params, options)
  end
  def make_req(type, path, params, options, retries) do
    try do
      case send_req(type, path, params, options) do
        {:error, _} -> make_retry(type, path, params, options, retries)
        result      -> result
      end
    catch
      _ -> make_retry(type, path, params, options, retries)
    rescue
      _ -> make_retry(type, path, params, options, retries)
    end
  end

  defp make_retry(type, path, params, options, retries) do
    :timer.sleep(@retry_time)
    make_req(type, path, params, options, retries - 1)
  end

  defp send_req(type, path, params, options) do
    IO.inspect "IN SEND_REQ"
    IO.inspect "TYPE"
    IO.inspect type
    IO.inspect "PARAMS"
    IO.inspect params
    IO.inspect "OPTIONS"
    IO.inspect options
    url = get_url(path, options[:driver_info])
    has_body = params != %{} && type == :post
    {headers, body} = cond do
       has_body && options[:json_encode] != false ->
        {[{"Content-Type", "text/json"}], Poison.encode!(params)}
      has_body ->
        {[], params}
      true ->
        {[], ""}
    end

    :hackney.request(type, url, headers, body, [:with_body | @http_options])
    |> handle_response({url, path, type}, options)
  end

  defp handle_response({:ok, code, headers, body}, {url, path, type}, options) do
    case Hound.ResponseParser.parse(response_parser(), path, code, headers, body) do
      :error ->
        raise """
        Webdriver call status code #{code} for #{type} request #{url}.
        Check if webdriver server is running. Make sure it supports the feature being requested.
        """
      {:error, err} = value ->
        if options[:safe],
          do: value,
          else: raise err
      response -> response
    end
  end

  defp handle_response({:error, reason}, _, _) do
    {:error, reason}
  end

  defp response_parser do
    IO.inspect "THE RESPONSE PARSER"
    {:ok, driver_info} = Hound.driver_info
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

  defp get_url(path, driver_info) do
    IO.inspect "GET_URL called"
    IO.inspect "PATH of get_url"
    IO.inspect path
    IO.inspect "DRIVER INFO PASSED INTO GET_URL"
    IO.inspect driver_info

    driver_info = if driver_info do
      driver_info
    else
      {:ok, driver_info} = Hound.driver_info
      driver_info
    end

    IO.inspect "AFTER IT HAS GONE THROUGH THE RINGER"
    IO.inspect driver_info

    host = driver_info[:host]
    port = driver_info[:port]
    path_prefix = driver_info[:path_prefix]

    "#{host}:#{port}/#{path_prefix}#{path}"
  end

end
