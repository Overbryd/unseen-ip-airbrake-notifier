
# identify_ip_protocol_port.rb

    #!/usr/bin/env ruby
    # identify_ip_port.rb: script to identify an ip port combination
    #
    # Usage:
    #
    #   $ ruby identify_ip_port.rb 8.8.8.8 udp 53
    #   {
    #     "ip": "8.8.8.8",
    #     "protocol": "udp",
    #     "port": "53",
    #     "service_name": "domain",
    #     "host": "google-public-dns-a.google.com"
    #   }
    #

# unseen_connections.rb

    #!/usr/bin/env ruby
    # unseen_connections.rb: script to notify unseen tcp connection attempts
    #
    # Usage:
    #
    #   elktail -f '%@timestamp,%src_ip,%dst_ip,%protocol,%src_port' 'type:cisco-firewall AND action:Built AND direction:outbound' \
    #   | ruby unseen_connections.rb
    #
    # Synopsis:
    #
    #   The script expects input on STDIN, one line per firewall log entry.
    #   Each line must be formatted, including the fields %@timestamp, %src_ip, %dst_ip, %protocol and %src_port.
    #
    #     %@timestamp,%src_ip,%dst_ip,%protocol,%src_port\n
    #
    #   e.g.
    #
    #     2016-11-29T10:36:05.990Z,50.31.164.146,10.248.177.12,TCP,443\n
    #
    #   It remembers each destination ip:port combination for a given time.
    #   Over multiple runs it restores and saves its state with a YAML file.
    #
    #   New ip:port combinations are reported to Airbrake with
    #   their respective environment and additional information.
    #
    #   Airbrake in turn alerts the current Sherrif in charge via Pivotaltracker.
    #
    # Dependencies:
    #
    #   * A tool that can stream data out of the ELK stack and format its output as described above.
    #     For example 'elktail' (https://github.com/knes1/elktail/releases) does the job really well.
    #
    #   * An Airbrake account project_id and project_key.
