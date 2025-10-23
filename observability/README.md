# Observability

Production-ready monitoring and observability setups for Temporal applications. This directory contains complete configurations for integrating Temporal metrics with popular observability platforms.

## [Grafana Setup](./grafana/GRAFANA_SETUP.md)

Configure OpenTelemetry Collector to scrape and forward Temporal metrics to Grafana. This setup provides flexible deployment options:

- **Local Grafana** - Docker-based Grafana and Prometheus stack, perfect for development with no cloud account needed
- **Grafana Cloud** - Managed service integration with free tier available for production monitoring
- **Hybrid Deployment** - Send metrics to both local and cloud simultaneously for testing and redundancy

The OpenTelemetry Collector scrapes Prometheus metrics from your Temporal workers and forwards them with proper formatting for Grafana dashboards.

## [DataDog Setup](./datadog/DATADOG_SETUP.md)

Integrate Temporal with DataDog using the DataDog Agent's OpenMetrics integration. This setup includes:

- **OpenMetrics Integration** - Converts Temporal histogram buckets to DataDog distributions for accurate percentile calculations (p50, p75, p95, p99)
- **Official Temporal Dashboard** - Pre-configured dashboard from the [Temporal dashboards repository](https://github.com/temporalio/dashboards) with automated upload script
- **Comprehensive Metrics** - Track workflow execution, activity latency, worker performance, and request metrics
- **Optional Features** - Enable logs collection, APM traces, and custom tagging for complete observability

Both solutions provide the metrics needed to monitor workflow health, debug performance issues, and set up alerts for production applications.

## Getting Started

1. Choose your observability platform (Grafana or DataDog)
2. Follow the setup guide for your chosen platform
3. Start your Temporal workers with metrics enabled
4. Verify metrics are flowing and create dashboards/alerts

## Metrics Available

Both platforms collect Temporal SDK metrics including:

- **Workflow Metrics** - Execution counts, durations, end-to-end latency
- **Activity Metrics** - Execution counts, failures, latency distributions
- **Worker Metrics** - Task queue polling, slot availability, task processing
- **Request Metrics** - gRPC request latency and failure rates

These metrics enable you to monitor application health, identify bottlenecks, and optimize performance.