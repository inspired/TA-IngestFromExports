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
1. Install this TA on your indexer/HF (source/intermediary system)
2. Install this TA on your (target system)
3. Move data from source system to target system whatever means you choose
4. Monitor, one-shot or upload files. Set sourcetype to ONE of the following:
   1. *rfs_input* (it will be rewritten) and set your desired index
   2. *rfs_input_with_index* (it will be rewritten) if you'd like to retain the original index.



## Use case 3: Ingest from Splunk JSON Export

### Introduction

Export your Splunk search results as JSON by clicking *Export Results*, Format: *JSON*

### Usage

1. Install this TA on your indexer/HF
2. Create your indexes
3. Monitor, one-shot or upload your CSV file. Set sourcetype to ONE of the following:
   1. *index_splunk_json_export* (it will be rewritten) and set your desired index
   2. *index_splunk_json_export_with_index* (it will be rewritten) if you'd like to retain the original index.

