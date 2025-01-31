# Splunk Add-on to ingest exports

Author: Mikael Bjerkeland, Splunk

Inspired by: https://github.com/silkyrich/ingest_eval_examples/ and https://community.splunk.com/t5/Getting-Data-In/How-to-get-the-host-value-from-INDEXED-EXTRACTIONS-json/m-p/577392

This TA has 3 use cases:
* Ingest from Exporttool CSV output
* Ingest from Ingest Actions Filesystem (RFS) Output
* Ingest from Splunk GUI export JSON output

## Use case 1: Ingest from Exporttool CSV output
https://github.com/Exporttool/exporttool

### Introduction
Exporttool creates CSV files in the following format:
| _time | source | host | sourcetype | _raw | _meta |
| ------------- | ------------- | ------------- | ------------- | ------------- | ------------- |
| 1733946871 | "source::XmlWinEventLog:Application" | "host::some.host.example.com" | "sourcetype::XmlWinEventLog" | "Event content, may be multi-line" | "_indextime::1734086604 punct::<_='://../////'><><_='___'/><_=''></><></><></><><" |

The props/transforms in this TA will rewrite the headers so that the event data, when ingested, matches the original data, and is ingested in the following format:

| _time | source | host | sourcetype | _raw |
| ------------- | ------------- | ------------- | ------------- | ------------- |
| 1733946871 | XmlWinEventLog:Application | some.host.example.com | XmlWinEventLog | Event content, may be multi-line, may contain any kind of special character like " etc |

The _meta is dropped and the other indexed fields are kept, with field values as on the source system.  
Splunkbase TAs will parse your data on the destination system just as they did on the source system.

### Usage

1. Install this TA on your indexer/HF
2. Create your indexes
3. Monitor, one-shot or upload your CSV file. Set sourcetype to *splunk_exporttool* (it will be rewritten)

   I.e.:
```
[monitor:///data/exports/windows/*]
sourcetype = splunk_exporttool
index = windows
```
4. Profit

## Use case 2: Ingest from Ingest Actions Filesystem (RFS) Output
See https://lantern.splunk.com/Splunk_Platform/Product_Tips/Data_Management/Using_file_system_destinations_with_file_system_as_a_buffer for detailed instructions.

Essentially this allows you to index and clone, or route a subset of data on your indexer/Heavy Forwarder to file system. The file system is essentially used as a buffer and files can be moved by other means to the target system, i.e. picked up by a Splunk Universal Forwarder or a file copy script.

Care has been taken to ensure that the integrity of the data is left intact, including metadata such as custom fields, allowing standard add-ons to parse the data on the target system.

### Usage

#### Splunk Setup
1. Install this TA on your indexer/HF (source/intermediary system)
    1. Configure outputs.conf with RFS Filesystem Output through the Ingest Actions GUI or with the following config file:
       ```
       [rfs:filesystem]
       compression = none
       dropEventsOnUploadError = false
       format = ndjson
       format.ndjson.index_time_fields = true
       fs.appendToFileUntilSizeMB = 250
       fs.timeBeforeClosingFileSecs = 30
       partitionBy = day,sourcetype
       path = file:///data/splunk
       ```
     2. Configure props.conf through the Ingest Actions GUI or with the following config files:
         1. props.conf
            ```
            [default]
            RULESET-Route_everyting_to_filesystem = _rule:Route_everyting_to_filesystem:route:eval:r2v8oeju
            ```
         2. transforms.conf
            ```
            [_rule:Route_everyting_to_filesystem:route:eval:r2v8oeju]
            INGEST_EVAL = 'pd:_destinationKey'=if((true()), "rfs:filesystem,_splunk_", 'pd:_destinationKey')
            STOP_PROCESSING_IF = NOT isnull('pd:_destinationKey') AND 'pd:_destinationKey' != "" AND (isnull('pd:_doRouteClone') OR 'pd:_doRouteClone' == "")
            ```
3. Install this TA on your (target system)
4. Move data from source system to target system using whatever means you choose. The attached [File move script](#move_files) can be used.
5. Monitor, batch or upload files. Set sourcetype to ONE of the following:
   1. *rfs_input* (it will be rewritten) and set your desired index
   2. *rfs_input_with_index* (it will be rewritten) if you'd like to retain the original index.
  ```
[batch:///data/imports]
move_policy = sinkhole
disabled = false
host = high-hf.localdomain
sourcetype = rfs_input_with_index
crcSalt = <SOURCE>
whitelist = \.ndjson(\.(zstd|zst|lz4|gzip))?$
```
  
#### <a name="move_files"></a> File move script
A convenience script to move files from one system to another using rsync+ssh is attached. The script also cleans up old files.  
The script is located in *bin/move_files.sh* and the unit files to execute it every 30 seconds are in the readme folder.

### Monitoring
If you are moving data across a network using the script bin/move_files.sh you can use the following to monitor latency and which files have been successfully read.  
Modify the paths and the replace function to match your setup.

```
earliest=-10m@m latest=-5m@m (index=main sourcetype=journald source="journald://SplunkCopyFiles" action=copytruncate) OR (index=_internal sourcetype=splunkd TailReader finished "/data/imports")
| eval file=trim(file,"'")
| eval file=replace(file,"//","/")
| eval file=replace(file,"/splunk/", "/imports/")
| eval file=replace(file,"(_\d+\.ndjson)",".ndjson")
| stats values(sourcetype) dc(sourcetype) AS dc_st range(_time) BY file
```

## Use case 3: Ingest from Splunk JSON Export

### Introduction
Export your Splunk search results as JSON by clicking *Export Results*, Format: *JSON*  
Search results have the following format (JSON prettified):

```
{
    "preview": false,
    "result": {
        "LastName": "Nordmann",
        "MachineDateTime": "2025-01-28 11:23:42.0",
        "TxnConditionName": "Granted Access",
        "TxnID": "12314124",
        "VisitorCard": "0",
        "WhereName": "1-1-5000",
        "_raw": "\"2025-01-28 11:23:42\" TxnID=\"12314124\", DeviceType=\"82\", ChainID=\"12\", NodeAddress=\"01\", DoorControlUnitID=\"1\", DeviceNumber=\"0\", AlarmEventType=\"0\", DeviceID=\"38\", NumberRepeats=\"0\", DateTimeOfTxn=\"2025-01-28 11:23:42.0\", DateTimeOfLastRepeat=\"NULL\", DateTimeOfReception=\"2025-01-28 11:23:42.0\", DateTimeOfProcessing=\"2025-01-28 11:23:42.0\", CompanyID=\"1\", CompanyName=\"ACME\", WhereName=\"1-1-5000\", PatrolTourID=\"0\", ResponseMnemonic=\"17238\", TxnConditionName=\"Granted Access\", AlarmPriority=\"30\", AlarmColour=\"255\", AlarmInstructionText=\"NULL\", CustomerCodeNumber=\"1000\", CardNumber=\"-128128128\", FirstName=\"Ola\", LastName=\"Nordmann\", AckedFlag=\"0\", AckedUserName=\"NULL\", AckedDateTime=\"NULL\", ResetFlag=\"0\", ResetDateTime=\"NULL\", ClearedFlag=\"0\", ClearedUserName=\"NULL\", ClearedDateTime=\"NULL\", ClearedAtMachine=\"NULL\", CommentFlag=\"0\", MachineID=\"0\", MachinePort=\"0\", TimeBefore=\"0\", TimeAfter=\"0\", MachineDateTime=\"2025-01-28 11:23:42.0\", EmployeeNumber=\"890005\", VisitorCard=\"0\", AckedTimeZoneCode=\"NULL\", ClearTimeZoneCode=\"NULL\", RegionID=\"NULL\", APTransactionID=\"0\", SubDeviceType=\"0\", SubDeviceID=\"0\", DriverID=\"0\", CardID=\"953121\", HasVideo=\"0\"\n",
        "_time": "2025-01-28T12:23:42.000+0100",
        "action": "success",
        "app": "Stanley:AC",
        "date_hour": "11",
        "date_mday": "28",
        "date_minute": "23",
        "date_month": "january",
        "date_second": "42",
        "date_wday": "tuesday",
        "date_year": "2025",
        "date_zone": "local",
        "dest": "Door_1-1-5000",
        "eventtype": "stanley-access_control",
        "host": "127.0.0.1",
        "index": "main",
        "linecount": "2",
        "product": "Access Control",
        "punct": "\"--_::\"_=\"\",_=\"\",_=\"\",_=\"\",_=\"\",_=\"\",_=\"\",_=\"\",_=\"",
        "source": "samplelog.access-log",
        "sourcetype": "access-log",
        "splunk_server": "ip-172-31-24-46.ec2.internal",
        "splunk_server_group": [
            "dmc_group_indexer",
            "dmc_group_kv_store",
            "dmc_group_license_master",
            "dmc_group_search_head"
        ],
        "src": "Door_1-1-5000",
        "src_nt_domain": "ACME",
        "tag": [
            "authentication",
            "physical",
            "success"
        ],
        "tag::action": "success",
        "tag::eventtype": [
            "authentication",
            "physical"
        ],
        "timeendpos": "20",
        "timestartpos": "1",
        "user": "890005",
        "vendor": "Stanley",
        "vendor_action": "17238",
        "vendor_product": "Stanley Access Control"
    }
}
```
Whereas we only want the following fields:
* _raw
* host
* sourcetype
* source
* index
* _time

### Usage

1. Install this TA on your indexer/HF
2. Create your indexes
3. Monitor, one-shot or upload your CSV file. Set sourcetype to ONE of the following:
   1. *index_splunk_json_export* (it will be rewritten) and set your desired index
   2. *index_splunk_json_export_with_index* (it will be rewritten) if you'd like to retain the original index.

