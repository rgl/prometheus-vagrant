this is a [Prometheus](https://prometheus.io/) and [Grafana](https://grafana.com/) playgound

# Usage

[Build and install the base image](https://github.com/rgl/windows-2016-vagrant).

Launch the `prometheus` machine:

```bash
vagrant up prometheus
```

Logon at the Windows console.

Prometheus is available at:

  [https://prometheus.example.com](https://prometheus.example.com)

[wmi_exporter](https://github.com/martinlindhe/wmi_exporter) is available at:

  [https://prometheus.example.com:9182](https://prometheus.example.com:9182)

**NB** It can only be accessed with a client certificate.

Grafana is available at:

  [https://grafana.example.com](https://grafana.example.com)

**NB** Login as `admin` and password `admin`.


# Reference

* [Exporters and their default port allocations](https://github.com/prometheus/prometheus/wiki/Default-port-allocations)
