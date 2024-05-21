"TimeLineHandlers": [
    {
      "HandlerType": "Watcher",
      "UtcTimeOn": "00:00:00",
      "UtcTimeOff": "24:00:00",
      "Loop": true,
      "TimeLineEvents": [
        {
          "Command": "folder",
          "CommandArgs": [ "path:%HOMEDRIVE%%HOMEPATH%\\Downloads", "size:2000", "deletionApproach:oldest" ],
          "DelayAfter": 0,
          "DelayBefore": 0
        }
      ]
    }
]
