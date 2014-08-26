##
# This module requires Metasploit: http//metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##

require 'msf/core'

class Metasploit3 < Msf::Auxiliary
  include Msf::Auxiliary::Report
  include Msf::Auxiliary::UDPScanner
  include Msf::Auxiliary::DRDoS

  def initialize
    super(
      'Name'        => 'SSDP ssdp:all Search Text Amplification Scanner',
      'Description' => 'Discover SSDP amplification possibilities',
      'Author'      => ['xistence <xistence[at]0x90.nl>'], # Original scanner module
      'License'     => MSF_LICENSE
    )

    register_options([
      Opt::RPORT(1900),
      OptBool.new('SHORT', [ false, "Does a shorter request, for a higher amplifier, not compatible with all devices", false])
    ], self.class)
  end

  def setup
    super
    # SSDP packet containing the "ST:ssdp:all" search query
    if datastore['short']
      # Short packet doesn't contain Host, MX and last \r\n
      @msearch_probe = "M-SEARCH * HTTP/1.1\r\nST:ssdp:all\r\nMan:\"ssdp:discover\"\r\n"
    else
      @msearch_probe = "M-SEARCH * HTTP/1.1\r\nHost:239.255.255.250:1900\r\nST:ssdp:all\r\nMan:\"ssdp:discover\"\r\nMX:5\r\n\r\n"
    end
  end

  def scanner_prescan(batch)
    print_status("Sending SSDP ssdp:all Search Text probes to #{batch[0]}->#{batch[-1]} (#{batch.length} hosts)")
    @results = {}
  end

  def scan_host(ip)
    scanner_send(@msearch_probe, ip, datastore['RPORT'])
  end

  def scanner_process(data, shost, sport)
    if data =~ /HTTP\/\d\.\d 200/
      @results[shost] ||= []
      @results[shost] << data
    end
  end

  # Called after the scan block
  def scanner_postscan(batch)
    @results.keys.each do |k|
      response_map = { @msearch_probe => @results[k] }
      report_service(
        host: k,
        proto: 'udp',
        port: datastore['RPORT'],
        name: 'ssdp'
      )

      peer = "#{k}:#{datastore['RPORT']}"
      vulnerable, proof = prove_drdos(response_map)
      what = 'SSDP ssdp:all DRDoS'
      if vulnerable
        print_good("#{peer} - Vulnerable to #{what}: #{proof}")
        report_vuln(
          host: k,
          port: datastore['RPORT'],
          proto: 'udp',
          name: what,
          refs: self.references
        )
      else
        vprint_status("#{peer} - Not vulnerable to #{what}: #{proof}")
      end
    end
  end
end
