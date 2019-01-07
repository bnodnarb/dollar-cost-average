# myapp.rb
require 'sinatra'
require 'json'
require 'uri'
require 'httparty'
require 'openssl'

get '/' do
  'Hello world!'
end

get '/order' do
  headers['Access-Control-Allow-Origin'] = '*'
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
