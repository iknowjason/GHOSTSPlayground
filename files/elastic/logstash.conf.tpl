# Beats -> Logstash -> Elasticsearch pipeline.
input {
  beats {
    port => 5044
  }
}

output {
  elasticsearch {
    ssl => true
    ssl_certificate_verification => false
    hosts => ["https://127.0.0.1:9200"]
    index => "logstash-%%{+YYYY.MM.dd}"
    user => "${elastic_username}"
    password => "${elastic_password}"
  }
}
