apiVersion: 1

deleteDatasources:

datasources:
- name: ghosts
  type: postgres
  url: ${ghosts_server}:5432
  database: ghosts
  user: ghosts
  secureJsonData:
    password: scotty@1
  isDefault: true
  jsonData:
    sslmode: disable
