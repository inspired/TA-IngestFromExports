# Add-on to correctly ingest CSVs produced by exporttool
https://github.com/Exporttool/exporttool

Author: Mikael Bjerkeland, Splunk

Inspired by: https://github.com/silkyrich/ingest_eval_examples/ and https://community.splunk.com/t5/Getting-Data-In/How-to-get-the-host-value-from-INDEXED-EXTRACTIONS-json/m-p/577392

## Introduction
Exporttool creates CSV files with the following content:
| "_time" | source | host | sourcetype | "_raw" | "_meta" |
| ------------- | ------------- | ------------- | ------------- | ------------- | ------------- |
| 1733946871 | "source::XmlWinEventLog:Application" | "host::some.host.example.com" | "sourcetype::XmlWinEventLog" | "Event content, may be multi-line" | "_indextime::1734086604 punct::<_='://../////'><><_='___'/><_=''></><></><></><><" |

The props/transforms in this TA will rewrite the headers so that the event data, when ingested, matches the original data, and is ingested in the following format:

| _time | source | host | sourcetype | _raw |
| ------------- | ------------- | ------------- | ------------- | ------------- |
| 1733946871 | XmlWinEventLog:Application | some.host.example.com | XmlWinEventLog | Event content, may be multi-line, may contain any kind of special character like " etc |

The _meta is dropped and the other indexed fields are kept, with field values as on the source system.  
Splunkbase TAs will parse your data on the destination system just as they did on the source system.

## Usage

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
