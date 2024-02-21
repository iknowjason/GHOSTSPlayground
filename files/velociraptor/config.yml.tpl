version:
  name: velociraptor
  version: 0.7.1-1
  commit: 2d7d6cf
  build_time: "2023-12-27T09:45:45Z"
  install_time: 1708354316
  ci_build_url: https://github.com/Velocidex/velociraptor/actions/runs/7337099704
  compiler: go1.21.5
Client:
  server_urls:
  - https://${velociraptor_ip}:8000/
  ca_certificate: |
    ${ca_crt}
  nonce: Llz3IMNsMHY=
  writeback_darwin: /etc/velociraptor.writeback.yaml
  writeback_linux: /etc/velociraptor.writeback.yaml
  writeback_windows: $ProgramFiles\Velociraptor\velociraptor.writeback.yaml
  level2_writeback_suffix: .bak
  tempdir_windows: $ProgramFiles\Velociraptor\Tools
  max_poll: 60
  nanny_max_connection_delay: 600
  windows_installer:
    service_name: Velociraptor
    install_path: $ProgramFiles\Velociraptor\Velociraptor.exe
    service_description: Velociraptor service
  darwin_installer:
    service_name: com.velocidex.velociraptor
    install_path: /usr/local/sbin/velociraptor
  version:
    name: velociraptor
    version: 0.7.1-1
    commit: 2d7d6cf
    build_time: "2023-12-27T09:45:45Z"
    install_time: 1708354316
    ci_build_url: https://github.com/Velocidex/velociraptor/actions/runs/7337099704
    compiler: go1.21.5
  use_self_signed_ssl: true
  pinned_server_name: VelociraptorServer
  max_upload_size: 5242880
  local_buffer:
    memory_size: 52428800
    disk_size: 1073741824
    filename_linux: /var/tmp/Velociraptor_Buffer.bin
    filename_windows: $TEMP/Velociraptor_Buffer.bin
    filename_darwin: /var/tmp/Velociraptor_Buffer.bin
API:
  hostname: localhost
  bind_address: 0.0.0.0 
  bind_port: 8001
  bind_scheme: tcp
  pinned_gw_name: GRPC_GW
GUI:
  bind_address: ${velociraptor_ip} 
  bind_port: 8889
  gw_certificate: |
    ${gw_crt}
  gw_private_key: |
    ${gw_key}
  public_url: https://${velociraptor_ip}:8889/
  links:
  - text: Documentation
    url: https://docs.velociraptor.app/
    icon_url: data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI1MyIgaGVpZ2h0PSI2MyIgdmVyc2lvbj0iMS4xIiB2aWV3Qm94PSIwIDAgNTMgNjMiPjxwYXRoIGQ9Ik0yNyAzYy0zIDItMTMgOC0yMyAxMGw2IDMyYTEwMyAxMDMgMCAwIDAgMTcgMTZsNi01IDExLTExIDYtMzJDMzkgMTEgMzAgNSAyNyAzeiIgZmlsbD0iI2ZmZiIgZmlsbC1ydWxlPSJldmVub2RkIi8+PHBhdGggZD0iTTI2IDBDMjMgMiAxMiA4IDAgMTBjMSA3IDUgMzIgNyAzNWExMTMgMTEzIDAgMCAwIDE5IDE4bDctNiAxMi0xMmMyLTMgNi0yOCA4LTM1QzQwIDggMjkgMiAyNiAwWm0wIDU1LTYtNC04LTktNS0yNnYtMWwyLTFjOC0xIDE2LTYgMTYtNmwxLTEgMSAxczggNSAxNyA2bDEgMXYxcy0zIDIzLTUgMjZsLTggOWMtMiAyLTQgNC02IDR6IiBmaWxsPSIjYWIwMDAwIiBmaWxsLW9wYWNpdHk9IjEiIGZpbGwtcnVsZT0iZXZlbm9kZCIvPjxwYXRoIGQ9Ik0zOSAxOWExMzQ3IDEzNDcgMCAwIDEtMTMgMjZoLTJMMTQgMTloM2wyIDEgMSAxdjFhMjUwIDI1MCAwIDAgMSA2IDE3IDUyODkgNTI4OSAwIDAgMCA5LTIwaDR6IiBmaWxsPSIjMDAwIiBmaWxsLXJ1bGU9ImV2ZW5vZGQiIHN0cm9rZT0iIzAwMCIgc3Ryb2tlLWRhc2hhcnJheT0ibm9uZSIgc3Ryb2tlLWxpbmVjYXA9ImJ1dHQiIHN0cm9rZS1saW5lam9pbj0ibWl0ZXIiIHN0cm9rZS13aWR0aD0iMSIvPjwvc3ZnPg==
    type: sidebar
    new_tab: true
  authenticator:
    type: Basic
CA:
  private_key: |
    ${ca_key}
Frontend:
  hostname: localhost
  bind_address: 0.0.0.0
  bind_port: 8000
  certificate: |
    ${fe_crt}
  private_key: |
    ${fe_key}
  dyn_dns: {}
  default_client_monitoring_artifacts:
  - Generic.Client.Stats
  GRPC_pool_max_size: 100
  GRPC_pool_max_wait: 60
  resources:
    connections_per_second: 100
    notifications_per_second: 30
    max_upload_size: 10485760
    expected_clients: 30000
Datastore:
  implementation: FileBaseDataStore
  location: /opt/velociraptor
  filestore_directory: /opt/velociraptor
Logging:
  output_directory: /opt/velociraptor/logs
  separate_logs_per_component: true
  debug:
    disabled: true
  info:
    rotation_time: 604800
    max_age: 31536000
  error:
    rotation_time: 604800
    max_age: 31536000
Monitoring:
  bind_address: ${velociraptor_ip} 
  bind_port: 8003
api_config: {}
server_type: linux
obfuscation_nonce: YSJqckGwSVA=
defaults:
  hunt_expiry_hours: 168
  notebook_cell_timeout_min: 10
