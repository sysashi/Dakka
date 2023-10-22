defmodule Dakka.Utils.HoneycombSampler do
  @behaviour OpentelemetryHoneycombSampler

  @impl OpentelemetryHoneycombSampler
  def description(_config), do: "Honeycomb Sampler"

  @impl OpentelemetryHoneycombSampler
  def setup(_config), do: []

  @impl OpentelemetryHoneycombSampler
  def sample_rate(
        _ctx,
        _trace_id,
        _links,
        _span_name,
        _span_kind,
        _span_attrs,
        _sampler_config
      ) do
    # 1 # all events will be sent
    # 2 # 50% of events will be sent
    # 3 # 33% of events will be sent
    # 4 # 25% of events will be sent
    1
  end
end
