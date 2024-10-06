defmodule Servy.Handler do
  @moduledoc """
  Handles HTTP requests.
  """

  alias Servy.Conv
  alias Servy.BearController
  alias Servy.VideoCam

  @pages_path Path.expand("../../pages", __DIR__)
  import Servy.Plugins, only: [ rewrite_path: 1, log: 1, track: 1 ]
  import Servy.Parser, only: [ parse: 1 ]

  @doc "Transforms a request into a response"
  def handle(request) do
    request
    |> parse
    |> rewrite_path
    # |> log
    |> route
    |> track
    |> format_response
  end

  def route(%Conv{ method: "POST", path: "/pledges"} = conv) do
    Servy.PledgeController.create(conv, conv.params)
  end

  def route(%Conv{ method: "GET", path: "/pledges"} = conv) do
    Servy.PledgeController.index(conv)
  end

  def route(%Conv{ method: "GET", path: "/sensors"} = conv) do
    task = Task.async(Servy.Tracker, :get_location, ["bigfoot"])
    snapshots =
      ["cam-1", "cam-2", "cam-3"]
      |> Enum.map(&Task.async(VideoCam, :get_snapshot, [&1]))
      |> Enum.map(&Task.await/1)

    where_is_bigfoot = Task.await(task)

    %{ conv | status: 200, resp_body: inspect {snapshots, where_is_bigfoot}}
  end

  def route(%Conv{method: "GET", path: "/kaboom"} = conv) do
    raise "Kaboom!"
  end

  def route(%Conv{method: "GET", path: "/hibernate/" <> time } = conv) do
    time |> String.to_integer |> :timer.sleep

    %{ conv | status: 200, resp_body: "Awake!" }
  end

  def route(%Conv{ method: "GET", path: "/wildthings"} = conv) do
    %{ conv | status: 200, resp_body: "Bears, Lions, Tigers"}
  end

  def route(%Conv{ method: "GET", path: "/api/bears"} = conv) do
    Servy.Api.BearController.index(conv)
  end

  def route(%Conv{ method: "GET", path: "/bears"} = conv) do
    BearController.index(conv)
  end


  def route(%Conv{ method: "GET", path: "/bears/" <> id } = conv) do
    params = Map.put(conv.params, "id", id)
    BearController.show(conv, params)
  end

  # name=Baloo&type=Brown
  def route(%Conv{method: "POST", path: "/bears"} = conv) do
    %{ conv | status: 201, resp_body: "Created a #{conv.params["type"]} bear named #{conv.params["name"]}!" }
  end


  def route(%Conv{ method: "GET", path: "/about" } = conv) do
      @pages_path
      |> Path.join("about.html")
      |> File.read
      |> handle_file(conv)
  end

  def route(%Conv{ path: path } = conv) do
    %{ conv | status: 404, resp_body: "No #{path} here!"}
  end

  def handle_file({:ok, content}, conv) do
    %{ conv | status: 200, resp_body: content}
  end

  def handle_file({:error, :enoent} , conv) do
    %{ conv | status: 404, resp_body: "File not found"}
  end

  def handle_file({:error, reason} , conv) do
    %{ conv | status: 404, resp_body: "File error: #{reason}" }
  end
  def format_response(%Conv{} =conv) do
    # TODO: Use values in the map to create an HTTP response string:
    """
    HTTP/1.1 #{Conv.full_status(conv)}\r
    Content-Type: #{conv.resp_content_type}\r
    Content-Length: #{String.length conv.resp_body}\r
    \r
    #{conv.resp_body}
    """
  end


end
