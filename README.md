# Tool to properly ingest CSVs produced by exporttool
https://github.com/Exporttool/exporttool

Author: Mikael Bjerkeland, Splunk
Inspired by: https://github.com/silkyrich/ingest_eval_examples/

## Usage

1. Create your index
2. Monitor, one-shot or upload your CSV file. Set sourcetype to *splunk_exporttool* (it will be rewritten)
```
[monitor:///data/exports/windows/*]
sourcetype = splunk_exporttool
```
3. Profit
