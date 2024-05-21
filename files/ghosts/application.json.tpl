{
  "ApiRootUrl": "http://${ghosts_server}:5000/api/clientid",
  "Sockets": {
    "IsEnabled": true,
    "Heartbeat": 50000
  },
  "Id": {
    "IsEnabled": true,
    "Format": "guestlocal",
    "FormatKey": "guestinfo.id",
    "FormatValue": "$formatkeyvalue$-$machinename$",
    "VMWareToolsLocation": "C:\\progra~1\\VMware\\VMware Tools\\vmtoolsd.exe"
  },
  "AllowMultipleInstances": false,
  "EncodeHeaders": true,
  "ClientResults": {
    "IsEnabled": true,
    "IsSecure": false,
    "CycleSleep": 300000
  },
  "ClientUpdates": {
    "IsEnabled": true,
    "CycleSleep": 300000
  },
  "Survey": {
    "IsEnabled": false,
    "IsSecure": false,
    "Frequency": "once",
    "CycleSleepMinutes": 5,
    "OutputFormat": "indent"
  },
  "Timeline": {
    "Location": "config/timeline.json"
  },
  "Content": {
    "EmailsMax": 20,
    "EmailContent": "",
    "EmailReply": "",
    "EmailDomain": "",
    "EmailOutside": "",
    "BlogContent": "",
    "BlogReply": "",
    "FileNames": "",
    "Dictionary": ""
  },
  "ResourceControl": {
    "ManageProcesses": true
  },
  "HealthIsEnabled": false,
  "HandlersIsEnabled": true,
  "DisableStartup": false
}
