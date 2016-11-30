#!/bin/sh
# cronjob.sh: script to invoke the unseen connections check periodically.
#
# Usage:
#
#   * * * * * /path/to/cronjob.sh "host-of-elasticsearch.logstash.com:9200"
#
# Dependencies:
#
#   * 'elktail' (https://github.com/knes1/elktail/releases) for streaming data out of logstash
#   * unseen_connections.rb for reporting unseen connections to Airbrake
#   * you can add custom query parameters to custom_query.sh, see custom_query.sh.example
#
# Limits:
#
#   Periodically polling for new log entries might return a lot of entries.
#   The number of entries returned is limited to 1000.
#   If more than 1000 new connections occur between two runs, only the last 1000 attempts are registered.

set -e

logstash_url="$1"
if [[ "$logstash_urlx" == "x" ]]; then
  echo "Please specify an url to your elasticsearch cluster holding the logstash indices"
  exit 1
fi

timefmt="%Y-%m-%dT%H:%M"
if [[ -f "unseen_connections.yml" ]]; then
  after=`date -u -r unseen_connections.yml +$timefmt`
else
  after=`date -u +$timefmt`
fi

query="type:cisco-firewall AND action:Built AND direction:outbound"
if [[ -f "custom_query.sh" ]]; then
  . custom_query.sh
fi

elktail --url "$logstash_url" --list-only -n 1000 --format '%@timestamp,%src_ip,%dst_ip,%protocol,%src_port' --after "$after" "$query" \
  | ruby unseen_connections.rb

