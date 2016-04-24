# infludbtools

Some tools to put data in InfluxDB from differents sources

## NAS Synology

synology/monitoring.pl

A perl script to process some of the /proc pseudo-files and send measurements to influxdb.

Simply copy the script in /home/admin (or elsewhere) and add a periodic task to run periodicly with parameters. Don't forget to change permisions on file to set it executable.

For example :
```
/volume1/homes/admin/monitoring.pl influxdb_server 8086 synology
```

## XPL protocol

TODO

## Fibaro Home Center

TODO

## CGE IPX 300

TODO
