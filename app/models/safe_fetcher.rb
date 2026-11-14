require "ipaddr"
require "net/http"
require "socket"

# Fetches a page from a URL a visitor typed, without letting that URL reach
# anything but the public web. It allows only http and https, refuses hosts
# that resolve to private or otherwise non-public addresses, connects to the
# exact address it checked (so a second DNS lookup can't swap in an internal
# one), re-checks every redirect, and caps time and size.
class SafeFetcher
  class Error < StandardError; end
  class InvalidUrl < Error; end
  class DisallowedAddress < Error; end
  class FetchFailed < Error; end

  MAX_BYTES = 2.megabytes
  MAX_REDIRECTS = 3
  TIMEOUT = 5
  USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
               "(KHTML, like Gecko) Chrome/130.0 Safari/537.36".freeze

  BLOCKED_RANGES = %w[
    0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12
    192.0.0.0/24 192.0.2.0/24 192.168.0.0/16 198.18.0.0/15 198.51.100.0/24
    203.0.113.0/24 224.0.0.0/4 240.0.0.0/4
    ::/128 ::1/128 64:ff9b::/96 100::/64 2001:db8::/32 fc00::/7 fe80::/10 ff00::/8
  ].map { |range| IPAddr.new(range) }.freeze

  mattr_accessor :resolver, default: ->(host) {
    Addrinfo.getaddrinfo(host, nil, nil, :STREAM, timeout: TIMEOUT).map(&:ip_address).uniq
  }
  mattr_accessor :total_timeout, default: 10

  def self.fetch(url)
    new.fetch(url)
  end

  def fetch(url)
    uri = parse(url)
    MAX_REDIRECTS.downto(0) do |redirects_left|
      body, location = get(uri, resolve(uri.hostname))
      return body unless location
      raise FetchFailed, "too many redirects" if redirects_left.zero?

      uri = parse(URI.join(uri, location).to_s)
    end
  end

  private
    def parse(url)
      uri = URI.parse(url.to_s.strip)
      raise InvalidUrl, url unless uri.is_a?(URI::HTTP) && uri.hostname.present?

      uri
    rescue URI::InvalidURIError
      raise InvalidUrl, url
    end

    def resolve(host)
      addresses = resolver.call(host).map { |address| IPAddr.new(address) }
      raise FetchFailed, "#{host} did not resolve" if addresses.empty?
      raise DisallowedAddress, host if addresses.any? { |address| blocked?(address) }

      addresses.first.to_s
    rescue SocketError, IPAddr::InvalidAddressError => error
      raise FetchFailed, error.message
    end

    def blocked?(address)
      address = address.native if address.ipv4_mapped?
      BLOCKED_RANGES.any? { |range| range.family == address.family && range.include?(address) }
    end

    # Returns [body, nil] for a page, or [nil, location] for a redirect.
    def get(uri, ip_address)
      http = Net::HTTP.new(uri.hostname, uri.port)
      http.ipaddr = ip_address
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = http.read_timeout = http.write_timeout = TIMEOUT
      http.max_retries = 0

      request = Net::HTTP::Get.new(uri, "User-Agent" => USER_AGENT, "Accept" => "text/html,application/xhtml+xml")
      http.start { http.request(request) { |response| return read(response) } }
    rescue Timeout::Error, SystemCallError, SocketError, IOError, OpenSSL::SSL::SSLError, Net::HTTPBadResponse, Net::ProtocolError => error
      raise FetchFailed, error.message
    end

    def read(response)
      case response
      when Net::HTTPRedirection
        location = response["location"]
        raise FetchFailed, "redirect without a location" if location.blank?

        [ nil, location ]
      when Net::HTTPSuccess
        [ read_body(response), nil ]
      else
        raise FetchFailed, "HTTP #{response.code}"
      end
    end

    def read_body(response)
      raise FetchFailed, "page too large" if response.content_length.to_i > MAX_BYTES

      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + total_timeout
      body = +""
      response.read_body do |chunk|
        body << chunk
        raise FetchFailed, "page too large" if body.bytesize > MAX_BYTES
        raise FetchFailed, "took too long" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      end
      body
    end
end
