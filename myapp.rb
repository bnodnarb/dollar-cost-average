require 'sinatra'

require_relative 'includes.rb'

get '/' do
  send_file File.join(settings.public_folder, 'index.html')
end

post '/generate_allocations' do
  content_type :json
  request.body.rewind
  request_payload = JSON.parse request.body.read

  LIMIT = request_payload['limit'].to_i
  TYPE = request_payload['type'].to_s
  UNBUFFERED_USDC_AMOUNT = request_payload['usdc_amount'].to_i
  USDC_AMOUNT = UNBUFFERED_USDC_AMOUNT - (UNBUFFERED_USDC_AMOUNT * BUFFER)

  ETH_USDC_PRICE = get_usdc_price_of_eth()
  BTC_USDC_PRICE = get_usdc_price_of_btc()

  binance_crypto_assets = get_binance_crypto_assets()
  coinmarketcap_crypto_assets = get_coinmarketcap_crypto_assets()

  relevant_crypto_assets = generate_relevant_crypto_assets(coinmarketcap_crypto_assets,binance_crypto_assets)
  overview = generate_overview(coinmarketcap_crypto_assets,binance_crypto_assets)
  allocations = generate_allocations(relevant_crypto_assets)
  orders = generate_orders(allocations)
  overview_allocations_and_orders = generate_overview_allocations_and_orders(overview,allocations,orders)

  overview_allocations_and_orders.to_json
end

post '/place_orders' do
  content_type :json
  request.body.rewind
  request_payload = JSON.parse request.body.read

  BASE_URL = 'https://api.binance.com'
  uri = URI("#{BASE_URL}/api/v3/order")

  request_payload.each do |order|
    symbol = order['symbol'].to_s
    side = order['side'].to_s
    type = order['type'].to_s
    quantity = order['quantity'].to_s
    timestamp = order['timestamp'].to_s
    signature = order['signature'].to_s
    api_key = order['api_key'].to_s
    recvWindow = order['recvWindow'].to_s

    params = {
        symbol: symbol,
        side: side,
        type: type,
        quantity: quantity,
        recvWindow: recvWindow,
        timestamp: timestamp,
        signature: signature
    }

    headers = {
      'X-MBX-APIKEY': api_key,
      'Content-Type': 'text/json'
    }

    binance_response = HTTParty.post(uri, headers: headers, body: params)

    order['response'] = JSON.parse(binance_response.body)
  end

  puts JSON.pretty_generate(request_payload)

  request_payload.to_json
end
