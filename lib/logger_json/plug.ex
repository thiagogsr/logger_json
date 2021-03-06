if Code.ensure_loaded?(Plug) do
  defmodule LoggerJSON.Plug do
    @moduledoc """
    A Plug to log request information in JSON format.
    """
    alias Plug.Conn
    alias LoggerJSON.Plug.MetadataFormatters
    require Logger

    @behaviour Plug

    @doc """
    Initializes the Plug.

    ### Available options

      * `:level` - log level which is used to log requests;
      * `:version_header` - request header which is used to determine API version requested by
      client, default: `x-api-version`;
      * `:metadata_formatter` - module with `build_metadata/3` function that formats the metadata
      before it's sent to logger, default - `LoggerJSON.Plug.MetadataFormatters.GoogleCloudLogger`.

    ### Available metadata formatters

      * `LoggerJSON.Plug.MetadataFormatters.GoogleCloudLogger` leverages GCP LogEntry format;
      * `LoggerJSON.Plug.MetadataFormatters.ELK` see module for logged structure.

    """
    @impl true
    def init(opts) do
      level = Keyword.get(opts, :log, :info)
      client_version_header = Keyword.get(opts, :version_header, "x-api-version")
      metadata_formatter = Keyword.get(opts, :metadata_formatter, MetadataFormatters.GoogleCloudLogger)
      filter_parameters = Keyword.get(opts, :filter_parameters, [])
      {level, metadata_formatter, client_version_header, filter_parameters}
    end

    @impl true
    def call(conn, {level, metadata_formatter, client_version_header, filter_parameters}) do
      start = System.monotonic_time()

      Conn.register_before_send(conn, fn conn ->
        latency = System.monotonic_time() - start
        metadata = metadata_formatter.build_metadata(conn, latency, client_version_header, filter_parameters)
        Logger.log(level, "", metadata)
        conn
      end)
    end

    @doc false
    def get_header(conn, header) do
      case Conn.get_req_header(conn, header) do
        [] -> nil
        [val | _] -> val
      end
    end
  end
end
