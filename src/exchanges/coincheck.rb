require "net/http"
require "uri"
require "openssl"
require "json"

class Coincheck
  def initialize
    @base_url = "https://coincheck.com"
    @BTC_JPY = "btc_jpy"
  end

  def start
    puts "#{@name} start"
    jpy_balance, btc_balance = get_balance
    btc_price = get_ticker
    puts "#{@name} end"
    return @name, jpy_balance, btc_balance, btc_price
  end

  def check_order_market(broker, price, amount, order_type)
    if order_type == "buy"
      order_market(market_buy_amount: price * amount, order_type: "market_buy", )
    else
      order_market(broker, amount: amount, order_type: "market_sell")
    end
  end

  def get_ticker(broker)
    uri = URI.parse(@base_url + "/api/ticker")
    headers = get_signature(uri, broker[:key], broker[:secret])
    response = request_for_get(uri, headers)
    return response["bid"].to_i, response["ask"].to_i
  end

  def get_order_book(broker)
    uri = URI.parse(@base_url + "/api/order_books")
    headers = get_signature(uri, broker[:key], broker[:secret])
    response = request_for_get(uri, headers)
    return response["bids"], response["asks"]
  end

  def get_balance(broker)
    uri = URI.parse(@base_url + "/api/accounts/balance")
    headers = get_signature(uri, broker[:key], broker[:secret])
    response = request_for_get(uri, headers)
    response["btc"].to_f.floor(3)
  end

  def get_order_status(broker)
    uri = URI.parse(@base_url + "/api/exchange/orders/opens")
    headers = get_signature(uri, broker[:key], broker[:secret])
    response = request_for_get(uri, headers)
    { broker: broker[:broker], order_status: response.dig("orders", 0, "id") }
  end

=begin
  def get_order_history(broker)
    uri = URI.parse(@base_url + "/api/exchange/orders/transactions_pagination")
    headers = get_signature(uri, broker[:key], broker[:secret])
    response = request_for_get(uri, headers)
    amount = response.dig("data", 0, "funds", "btc").to_f
    if amount > 0
      order_type = "buy"
    else
      order_type = "sell"
    end

    return {broker: broker[:broker], amount: amount.abs, order_type: order_type }
  end
=end

  def order_market(broker, price: nil, amount:nil, order_type: nil, market_buy_amount: nil)
    uri = URI.parse(@base_url + "/api/exchange/orders")
    body = {
      rate: price,
      market_buy_amount: market_buy_amount,
      amount: amount,
      order_type: order_type,
      pair: @BTC_JPY
    }.to_json
    headers = get_signature(uri, broker[:key], broker[:secret], body)
    request_for_post(uri, headers, body)
  end

  def cancel_order(broker)
    uri = URI.parse(@base_url + "/api/exchange/orders/#{broker['id']}")
    headers = get_signature(uri, broker[:key], broker[:secret])
    response = request_for_delete(uri, headers)
  end

  def get_signature(uri, key, secret, body = "")
    timestamp = Time.now.to_i.to_s
    message = timestamp + uri.to_s + body
    signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), secret, message)
    headers = {
      "ACCESS-KEY" => key,
      "ACCESS-NONCE" => timestamp,
      "ACCESS-SIGNATURE" => signature
    }
  end

  def request_for_get(uri, headers = {})
    request = Net::HTTP::Get.new(uri.request_uri, initheader = custom_header(headers))
    request_http(uri, request)
  end

  def request_for_post(uri, headers = {}, body)
    request = Net::HTTP::Post.new(uri.request_uri, initheader = custom_header(headers))
    request.body = body
    request_http(uri, request)
  end

  def request_for_delete(uri, headers = {})
    request = Net::HTTP::Delete.new(uri.request_uri, initheader = custom_header(headers))
    request_http(uri, request)
  end

  def custom_header(headers = {})
    headers.merge!({
      "Content-Type" => "application/json",
      "User-Agent" => "RubyCoincheckClient v0.3.0"
    })
  end

  def request_http(uri, request)
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    response = https.start { |http| http.request(request) }
    JSON.parse(response.body)
  end
end
