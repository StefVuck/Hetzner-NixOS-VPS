{ config, pkgs, ... }:

let
  secrets = import ../secrets.nix;
in
{
  # Prometheus
  services.prometheus = {
    enable = true;
    port = 9090;
    retentionTime = "30d";

    exporters = {
      node = {
        enable = true;
        enabledCollectors = [ "systemd" "processes" ];
        port = 9100;
      };

      nginx = {
        enable = true;
        port = 9113;
        scrapeUri = "http://localhost/nginx_status";
      };
    };

    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [{
          targets = [ "localhost:${toString config.services.prometheus.exporters.node.port}" ];
        }];
      }
      {
        job_name = "nginx";
        static_configs = [{
          targets = [ "localhost:${toString config.services.prometheus.exporters.nginx.port}" ];
        }];
      }
      {
        job_name = "prometheus";
        static_configs = [{
          targets = [ "localhost:${toString config.services.prometheus.port}" ];
        }];
      }
    ];
  };

  # Loki
  services.loki = {
    enable = true;

    configuration = {
      server.http_listen_port = 3100;
      auth_enabled = false;

      ingester = {
        lifecycler = {
          address = "127.0.0.1";
          ring = {
            kvstore.store = "inmemory";
            replication_factor = 1;
          };
        };
        chunk_idle_period = "5m";
        chunk_retain_period = "30s";
      };

      schema_config = {
        configs = [{
          from = "2024-01-01";
          store = "tsdb";
          object_store = "filesystem";
          schema = "v13";
          index = {
            prefix = "index_";
            period = "24h";
          };
        }];
      };

      storage_config = {
        tsdb_shipper = {
          active_index_directory = "/var/lib/loki/tsdb-index";
          cache_location = "/var/lib/loki/tsdb-cache";
        };
        filesystem.directory = "/var/lib/loki/chunks";
      };

      compactor = {
        working_directory = "/var/lib/loki/compactor";
        compaction_interval = "10m";
      };

      limits_config = {
        reject_old_samples = true;
        reject_old_samples_max_age = "168h";
      };
    };
  };

  # Promtail
  services.promtail = {
    enable = true;

    configuration = {
      server = {
        http_listen_port = 9080;
        grpc_listen_port = 0;
      };

      positions.filename = "/var/lib/promtail/positions.yaml";

      clients = [{
        url = "http://127.0.0.1:${toString config.services.loki.configuration.server.http_listen_port}/loki/api/v1/push";
      }];

      scrape_configs = [
        {
          job_name = "journal";
          journal = {
            max_age = "12h";
            labels = {
              job = "systemd-journal";
              host = "vps";
            };
          };
          relabel_configs = [{
            source_labels = [ "__journal__systemd_unit" ];
            target_label = "unit";
          }];
        }
        {
          job_name = "nginx";
          static_configs = [{
            targets = [ "localhost" ];
            labels = {
              job = "nginx";
              __path__ = "/var/log/nginx/*.log";
            };
          }];
        }
      ];
    };
  };

  # Grafana
  services.grafana = {
    enable = true;

    settings = {
      server = {
        http_addr = "127.0.0.1";
        http_port = 3001;
        domain = "grafana.${secrets.domains.main}";
        root_url = "https://grafana.${secrets.domains.main}";
      };

      security = {
        admin_user = "admin";
        admin_password = secrets.grafana.adminPassword;
      };

      analytics.reporting_enabled = false;
    };

    provision = {
      enable = true;

      datasources.settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          access = "proxy";
          url = "http://127.0.0.1:${toString config.services.prometheus.port}";
          isDefault = true;
        }
        {
          name = "Loki";
          type = "loki";
          access = "proxy";
          url = "http://127.0.0.1:${toString config.services.loki.configuration.server.http_listen_port}";
        }
      ];

      dashboards.settings = {
        apiVersion = 1;
        providers = [{
          name = "default";
          orgId = 1;
          folder = "";
          type = "file";
          disableDeletion = false;
          updateIntervalSeconds = 10;
          allowUiUpdates = true;
          options.path = "/var/lib/grafana/dashboards";
        }];
      };
    };
  };

  # Create required directories
  systemd.tmpfiles.rules = [
    "d /var/lib/grafana/dashboards 0755 grafana grafana -"
    "d /var/lib/promtail 0755 promtail promtail -"
  ];

  # Download dashboards on system activation
  system.activationScripts.grafanaDashboards = ''
    mkdir -p /var/lib/grafana/dashboards

    # Node Exporter Full (Dashboard ID: 1860) - System metrics
    if [ ! -f /var/lib/grafana/dashboards/node-exporter-full.json ]; then
      ${pkgs.curl}/bin/curl -s https://grafana.com/api/dashboards/1860/revisions/37/download -o /var/lib/grafana/dashboards/node-exporter-full.json
    fi

    # Nginx Metrics (Dashboard ID: 12708) - Nginx performance metrics
    if [ ! -f /var/lib/grafana/dashboards/nginx-metrics.json ]; then
      ${pkgs.curl}/bin/curl -s https://grafana.com/api/dashboards/12708/revisions/1/download -o /var/lib/grafana/dashboards/nginx-metrics.json
    fi

    # Service Logs Dashboard - Multi-panel view for all services
    cat > /var/lib/grafana/dashboards/simple-loki-logs.json << 'EOF'
{
  "annotations": {"list": []},
  "editable": true,
  "fiscalYearStartMonth": 0,
  "graphTooltip": 0,
  "id": null,
  "links": [],
  "liveNow": false,
  "panels": [
    {
      "datasource": {"type": "loki", "uid": "Loki"},
      "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
      "id": 1,
      "options": {
        "dedupStrategy": "none",
        "enableLogDetails": true,
        "prettifyLogMessage": false,
        "showCommonLabels": false,
        "showLabels": false,
        "showTime": true,
        "sortOrder": "Descending",
        "wrapLogMessage": false
      },
      "targets": [{"datasource": {"type": "loki", "uid": "Loki"}, "editorMode": "code", "expr": "{job=\"nginx\"}", "queryType": "range", "refId": "A"}],
      "title": "Nginx Access Logs",
      "type": "logs"
    },
    {
      "datasource": {"type": "loki", "uid": "Loki"},
      "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0},
      "id": 2,
      "options": {
        "dedupStrategy": "none",
        "enableLogDetails": true,
        "prettifyLogMessage": false,
        "showCommonLabels": false,
        "showLabels": false,
        "showTime": true,
        "sortOrder": "Descending",
        "wrapLogMessage": false
      },
      "targets": [{"datasource": {"type": "loki", "uid": "Loki"}, "editorMode": "code", "expr": "{job=\"systemd-journal\", unit=\"nginx.service\"}", "queryType": "range", "refId": "A"}],
      "title": "Nginx Service Logs",
      "type": "logs"
    },
    {
      "datasource": {"type": "loki", "uid": "Loki"},
      "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8},
      "id": 3,
      "options": {
        "dedupStrategy": "none",
        "enableLogDetails": true,
        "prettifyLogMessage": false,
        "showCommonLabels": false,
        "showLabels": false,
        "showTime": true,
        "sortOrder": "Descending",
        "wrapLogMessage": false
      },
      "targets": [{"datasource": {"type": "loki", "uid": "Loki"}, "editorMode": "code", "expr": "{job=\"systemd-journal\", unit=\"grafana.service\"}", "queryType": "range", "refId": "A"}],
      "title": "Grafana Service",
      "type": "logs"
    },
    {
      "datasource": {"type": "loki", "uid": "Loki"},
      "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8},
      "id": 4,
      "options": {
        "dedupStrategy": "none",
        "enableLogDetails": true,
        "prettifyLogMessage": false,
        "showCommonLabels": false,
        "showLabels": false,
        "showTime": true,
        "sortOrder": "Descending",
        "wrapLogMessage": false
      },
      "targets": [{"datasource": {"type": "loki", "uid": "Loki"}, "editorMode": "code", "expr": "{job=\"systemd-journal\", unit=\"prometheus.service\"}", "queryType": "range", "refId": "A"}],
      "title": "Prometheus Service",
      "type": "logs"
    },
    {
      "datasource": {"type": "loki", "uid": "Loki"},
      "gridPos": {"h": 8, "w": 12, "x": 0, "y": 16},
      "id": 5,
      "options": {
        "dedupStrategy": "none",
        "enableLogDetails": true,
        "prettifyLogMessage": false,
        "showCommonLabels": false,
        "showLabels": false,
        "showTime": true,
        "sortOrder": "Descending",
        "wrapLogMessage": false
      },
      "targets": [{"datasource": {"type": "loki", "uid": "Loki"}, "editorMode": "code", "expr": "{job=\"systemd-journal\", unit=\"loki.service\"}", "queryType": "range", "refId": "A"}],
      "title": "Loki Service",
      "type": "logs"
    },
    {
      "datasource": {"type": "loki", "uid": "Loki"},
      "gridPos": {"h": 8, "w": 12, "x": 12, "y": 16},
      "id": 6,
      "options": {
        "dedupStrategy": "none",
        "enableLogDetails": true,
        "prettifyLogMessage": false,
        "showCommonLabels": false,
        "showLabels": false,
        "showTime": true,
        "sortOrder": "Descending",
        "wrapLogMessage": false
      },
      "targets": [{"datasource": {"type": "loki", "uid": "Loki"}, "editorMode": "code", "expr": "{job=\"systemd-journal\", unit=\"promtail.service\"}", "queryType": "range", "refId": "A"}],
      "title": "Promtail Service",
      "type": "logs"
    }
  ],
  "refresh": "10s",
  "schemaVersion": 38,
  "style": "dark",
  "tags": ["loki", "logs", "services"],
  "templating": {"list": []},
  "time": {"from": "now-1h", "to": "now"},
  "timepicker": {},
  "timezone": "",
  "title": "Service Logs",
  "uid": "simple-loki-logs",
  "version": 0,
  "weekStart": ""
}
EOF

    chown -R grafana:grafana /var/lib/grafana/dashboards
    chmod 644 /var/lib/grafana/dashboards/*.json
  '';
}
