this is a [Prometheus](https://prometheus.io/) and [Grafana](https://grafana.com/) playgound

# Usage

[Build and install the base image](https://github.com/rgl/windows-2016-vagrant).

Launch the `prometheus` machine:

```bash
vagrant up prometheus --provider=virtualbox # or --provider=libvirt
```

Logon at the Windows console.

Prometheus is available at:

  [https://prometheus.example.com](https://prometheus.example.com)

[Alertmanager](https://github.com/prometheus/alertmanager) is available at:

  [https://alertmanager.example.com](https://alertmanager.example.com)

**NB** Alert emails are sent to a local SMTP server and can be seen at [http://localhost:8025](http://localhost:8025).

Grafana is available at:

  [https://grafana.example.com](https://grafana.example.com)

**NB** Login as `admin` and password `admin`.

Exporters are listening in the loopback interface and are made available from the caddy reverse proxy (which requires a client certificate):

| Exporter                                                                          | Address                                           |
|-----------------------------------------------------------------------------------|---------------------------------------------------|
| [blackbox_exporter](https://github.com/prometheus/blackbox_exporter)              | https://prometheus.example.com:9009/blackbox      |
| [PerformanceCountersExporter](https://github.com/rgl/PerformanceCountersExporter) | https://prometheus.example.com:9009/pce/metrics   |
| [PowerShellExporter](https://github.com/rgl/PowerShellExporter)                   | https://prometheus.example.com:9009/pse/metrics   |
| [wmi_exporter](https://github.com/martinlindhe/wmi_exporter)                      | https://prometheus.example.com:9009/wmi/metrics   |

# Reference

* [Exporters and their default port allocations](https://github.com/prometheus/prometheus/wiki/Default-port-allocations)
