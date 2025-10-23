# DataDog Observability Setup

This guide walks you through setting up the DataDog Agent to collect and forward Temporal .NET metrics to DataDog.

## Prerequisites

- Docker and Docker Compose installed
- Your Temporal .NET worker running and exposing Prometheus metrics (port 9464)
- A DataDog account (free trial available at https://www.datadoghq.com/)

## Quick Start

### Step 1: Get Your DataDog API Key

1. Log into your DataDog account
2. Navigate to **Organization Settings** → **API Keys**
3. Or go directly to: https://app.datadoghq.com/organization-settings/api-keys
4. Create a new API key or copy an existing one

### Step 2: Configure Environment Variables

Copy the sample environment file and add your credentials:

```bash
cd datadog
cp .env.sample .env
```

Edit `.env` and set your API key:

```bash
DD_API_KEY=your_actual_api_key_here
DD_SITE=datadoghq.com  # Change based on your region (see .env.sample for options)
```

### Step 3: Start the DataDog Agent

```bash
cd datadog
docker compose up -d

# View logs to verify it's running
docker compose logs -f datadog-agent
```

You should see log messages indicating:
- The agent has started successfully
- It's connected to DataDog
- It's scraping metrics from your Temporal worker (port 9464)

### Step 4: Start Your Temporal Worker

Make sure your Temporal .NET worker is running and exposing metrics:

```bash
cd src/Onboardings/Onboardings.Workers
dotnet run --configuration=LocalWorker
```

The worker will expose Prometheus metrics on port 9464 (as configured in TemporalExtensions.cs).

### Step 5: Verify Metrics in DataDog

1. Log into your DataDog dashboard: https://app.datadoghq.com
2. Go to **Metrics** → **Explorer**
3. Search for metrics starting with `temporal.*`:
   - `temporal.workflow.*`
   - `temporal.activity.*`
   - `temporal.request.*`
4. Filter by tag: `service:temporal-worker`

It may take 2-3 minutes for metrics to first appear in DataDog.

### Step 6: (Optional) Install the Temporal SDK Dashboard

We've included a script to automatically upload the official Temporal SDK dashboard to your DataDog account:

```bash
cd datadog
chmod +x setup-dashboard.sh
./setup-dashboard.sh
```

This requires:
- `DD_API_KEY` - Your DataDog API key (already in .env)
- `DD_APP_KEY` - Your DataDog Application key (add to .env)

To get your Application Key:
1. Go to https://app.datadoghq.com/organization-settings/application-keys
2. Create a new Application Key
3. Add it to your `.env` file as `DD_APP_KEY=your_app_key_here`

The script will:
- Upload the dashboard from `dashboards/temporal-core-sdk.json`
- Provide the dashboard URL
- List which metrics need percentiles enabled

**Note:** The dashboard is stored locally in `dashboards/temporal-core-sdk.json` from the [official Temporal dashboards repository](https://github.com/temporalio/dashboards/blob/master/sdk/datadog/temporal_sdk_dashboard.json).

## Configuration

### OpenMetrics Configuration

The DataDog agent uses the **OpenMetrics integration** (not Prometheus) to scrape metrics from your Temporal worker. This is important because:

- **Converts histogram buckets to DataDog distributions** - enables percentile calculations (p50, p75, p95, p99)
- **Works with Temporal's official DataDog dashboard** - https://github.com/temporalio/dashboards
- **Better metric representation** for latency and timing metrics

Configuration is in:
- `conf.d/openmetrics.d/conf.yaml` - OpenMetrics scrape configuration

After metrics start flowing, **enable percentiles in DataDog**:
1. Go to https://app.datadoghq.com/metric/summary
2. Search for `temporal_request_latency`, `temporal_workflow_endtoend_latency`, etc.
3. Click each metric → **Advanced** → **Percentiles** → **Configure** → Enable p95, p99

### Custom Tags

Add custom tags to organize your metrics by editing `.env`:

```bash
DD_TAGS=env:production,team:platform,region:us-east-1
```

### Enable Logs Collection

To collect container logs:

```bash
# In .env file
DD_LOGS_ENABLED=true
DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL=true
```

### Enable APM (Traces)

To enable Application Performance Monitoring:

```bash
# In .env file
DD_APM_ENABLED=true
```

Then configure your application to send traces to `localhost:8126`.

## Troubleshooting

### Agent can't reach worker metrics

If you see errors about connecting to `host.docker.internal:9464`:

**On Linux**: Replace `host.docker.internal` with your machine's IP or `172.17.0.1` in `conf.d/openmetrics.d/conf.yaml`:
```yaml
- openmetrics_endpoint: http://172.17.0.1:9464/metrics
```

**On macOS/Windows**: `host.docker.internal` should work out of the box.

### No metrics appearing in DataDog

1. Check agent logs: `docker compose logs datadog-agent`
2. Verify worker is exposing metrics: `curl http://localhost:9464/metrics`
3. Check your API key is valid and has proper permissions
4. Verify your DataDog site URL is correct for your region
5. Wait 2-3 minutes - there can be a delay on first metric ingestion

### Authentication errors

If you see 403 errors in agent logs:
- Verify your `DD_API_KEY` is correct
- Make sure the API key is active in DataDog
- Check you're using the correct `DD_SITE` for your region

### Check Agent Status

To see the agent's internal status:

```bash
docker compose exec datadog-agent agent status
```

This shows:
- Connection status to DataDog
- Running checks (including Prometheus)
- Metric collection statistics

## Customization

### Add Multiple Worker Endpoints

To scrape metrics from multiple Temporal workers, edit `conf.d/openmetrics.d/conf.yaml` and uncomment/add additional instances:

```yaml
instances:
  # Worker 1
  - openmetrics_endpoint: http://host.docker.internal:9464/metrics
    tags:
      - "service:temporal-worker"
      - "worker_instance:worker-1"
    metrics:
      - "temporal_*"
    histogram_buckets_as_distributions: true
    # ... (other config)

  # Worker 2
  - openmetrics_endpoint: http://host.docker.internal:9465/metrics
    tags:
      - "service:temporal-worker"
      - "worker_instance:worker-2"
    metrics:
      - "temporal_*"
    histogram_buckets_as_distributions: true
    # ... (other config)
```

Each instance will send metrics to DataDog with the appropriate `worker_instance` tag for filtering.

### Add More Prometheus Endpoints

To scrape non-Temporal metrics, add additional instances in `conf.d/openmetrics.d/conf.yaml`:

```yaml
instances:
  - prometheus_url: http://host.docker.internal:9464/metrics
    namespace: temporal
    metrics:
      - temporal_*
    tags:
      - service:temporal-worker

  # Add another endpoint
  - prometheus_url: http://host.docker.internal:9090/metrics
    namespace: my_service
    metrics:
      - my_*
    tags:
      - service:my-service
```

### Metric Type Overrides

If metrics aren't appearing correctly, you can override their types in `conf.d/prometheus.d/conf.yaml`:

```yaml
type_overrides:
  temporal_workflow_completed: counter
  temporal_workflow_endtoend_latency: histogram
  temporal_worker_task_slots_available: gauge
```

## Stopping the Agent

```bash
cd datadog
docker compose down
```

## Architecture

```
Temporal .NET Worker (localhost:9464)
         ↓ (scrape every 15s)
DataDog Agent (Docker)
         ↓ (forward metrics)
DataDog Cloud
         ↓
DataDog Dashboards & Monitors
```

## Next Steps

- Create DataDog dashboards for your Temporal metrics
- Set up monitors and alerts for workflow failures or high latency
- Enable APM to trace workflow and activity execution
- Set up log collection for complete observability
- Explore DataDog's built-in integrations and visualizations

## Additional Resources

- DataDog Agent Documentation: https://docs.datadoghq.com/agent/
- Prometheus Check: https://docs.datadoghq.com/integrations/prometheus/
- OpenMetrics Check: https://docs.datadoghq.com/integrations/openmetrics/
- DataDog Metrics: https://docs.datadoghq.com/metrics/