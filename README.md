this is a [Prometheus](https://prometheus.io/) and [Grafana](https://grafana.com/) playgound

# Usage

[Build and install the base image](https://github.com/rgl/windows-2016-vagrant).

Launch the `prometheus` machine:

```bash
vagrant up prometheus
```

Logon at the Windows console.

Prometheus is available at:

  [http://localhost:9090](http://localhost:9090)

[wmi_exporter](https://github.com/martinlindhe/wmi_exporter) is available at:

  [http://localhost:9182](http://localhost:9182)

Grafana is available at:

  [http://localhost:3000](http://localhost:3000)

**NB** Login as `admin` and password `admin`.
