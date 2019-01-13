require 'sinatra'

require_relative 'includes.rb'

get '/' do
  send_file File.join(settings.public_folder, 'index.html')
end

get '/createTransaction' do
  send_file File.join(settings.public_folder, 'createTransaction.html')
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

  # request_payload.to_json
end

get '/order' do
  content_type :json
  symbol = params[:symbol].to_s
  side = params[:side].to_s
  type = params[:type].to_s
  quantity = params[:quantity].to_s
  timestamp = params[:timestamp].to_s
  signature = params[:signature].to_s
  api_key = params[:api_key].to_s
  recvWindow = params[:recvWindow].to_s

  params = {
      symbol: symbol,
      side: side,
      type: type,
      quantity: quantity,
      recvWindow: recvWindow,
      timestamp: timestamp,
      signature: signature
  }

  BASE_URL = 'https://api.binance.com'
  uri = URI("#{BASE_URL}/api/v3/order")

  headers = {
    'X-MBX-APIKEY': api_key,
    'Content-Type': 'text/json'
  }

  binance_response = HTTParty.post(uri, headers: headers, body: params)

  binance_response.body

end
