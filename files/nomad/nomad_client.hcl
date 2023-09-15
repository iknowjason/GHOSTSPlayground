
data_dir  = "C:\\Tools\\nomad"
bind_addr = "0.0.0.0"
datacenter = "nomad1"

advertise {
  http = "IP_ADDRESS"
  rpc  = "IP_ADDRESS"
  serf = "IP_ADDRESS"
}

acl {
  enabled = true
}

client {
  enabled = true
  server_join {
    retry_join = ["${retry_join_ips}"]
  }
}

plugin "raw_exec" {
  config {
    enabled = true
  }
}
