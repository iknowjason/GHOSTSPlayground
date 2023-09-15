
job "ping-job" {
  datacenters = ["nomad1"]
  type = "batch"

  group "ping-group" {
    task "ping-task" {
      driver = "raw_exec"

      config {
        command = "cmd"
        args = ["/c", "ping", "66.228.48.29", "-n", "5"]
      }

      resources {
        cpu = 500
        memory = 256
      }
    }
  }
}

