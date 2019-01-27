def count_decimal_places(value)
  if value.to_s.include? '.'
    if value.to_s.split('.').last == '0'
      return 0
    else
      return value.to_s.split('.').last.size
    end
  else
    return 0
  end
end

class Float
  def floor2(exp = 0)
   multiplier = 10 ** exp
   ((self * multiplier).floor).to_f/multiplier.to_f
  end

  def ceil2(exp = 0)
   multiplier = 10 ** exp
   ((self * multiplier).ceil).to_f/multiplier.to_f
  end
end

#new work

def get_binance_pair_price(base_asset_symbol,quote_asset_symbol)
  uri = URI.parse("https://api.binance.com/api/v1/ticker/price?symbol=#{base_asset_symbol}#{quote_asset_symbol}")
  response = Net::HTTP.get_response(uri)
  return JSON.parse(response.body)['price'].to_f
end

def get_usdc_price_of_btc()
  return get_binance_pair_price('BTC','USDC')
end

def get_usdc_price_of_eth()
  return get_binance_pair_price('ETH','USDC')
end

def get_binance_crypto_assets()
  uri = URI.parse('https://api.binance.com/api/v1/exchangeInfo')
  response = Net::HTTP.get_response(uri)
  return JSON.parse(response.body)
end

def get_coinmarketcap_crypto_assets()
  uri = URI.parse("https://pro-api.coinmarketcap.com/v1/cryptocurrency/listings/latest?CMC_PRO_API_KEY=#{CMC_API_KEY}&cryptocurrency_type=#{TYPE}&limit=#{RESULT_LIMIT}")
  response = Net::HTTP.get_response(uri)
  return JSON.parse(response.body)['data']
end

def crypto_asset_on_binance?(binance_crypto_assets,symbol)
  if x = binance_crypto_assets['symbols'].find { |x| x['baseAsset'] == symbol && x['status'] == 'TRADING'}
    return true
  else
    return false
  end
end

def get_aligned_crypto_asset_symbol(symbol)
  case symbol
  when 'MIOTA'
    return 'IOTA'
  when 'BCH'
    return 'BCHABC'
  when 'BSV'
    return 'BCHSV'
  else
    return symbol
  end
end

def get_relevant_crypto_assets(coinmarketcap_crypto_assets,binance_crypto_assets)
  relevant_crypto_assets = []
  i = 0
  coinmarketcap_crypto_assets.each do |coinmarketcap_crypto_asset|
    aligned_symbol = get_aligned_crypto_asset_symbol(coinmarketcap_crypto_asset['symbol'])
    if crypto_asset_on_binance?(binance_crypto_assets,aligned_symbol)
      relevant_crypto_assets << coinmarketcap_crypto_asset
      i += 1
      if i >= LIMIT
        return relevant_crypto_assets
      end
    else
    end
  end
end

def get_relevant_market_cap(relevant_crypto_assets)
  relevant_market_cap = 0
  relevant_crypto_assets.each do |relevant_crypto_asset|
    relevant_market_cap += relevant_crypto_asset['quote']['USD']['market_cap'].to_f
  end
  return relevant_market_cap
end

def get_total_market_cap(coinmarketcap_crypto_assets)
  total_market_cap = 0
  cmc_assets_without_blacklisted_crypto_assets = remove_blacklisted_crypto_assets_from_coinmarketcap_crypto_assets(coinmarketcap_crypto_assets)
  cmc_assets_without_blacklisted_crypto_assets.each do |cmc_assets_without_blacklisted_crypto_asset|
    total_market_cap += cmc_assets_without_blacklisted_crypto_asset['quote']['USD']['market_cap'].to_f
  end
  return total_market_cap
end

def get_market_coverage(relevant_market_cap,total_market_cap)
  return (relevant_market_cap / total_market_cap).round(4) * 100
end

def get_precise_allocation_percentage(relevant_crypto_assets,symbol)
  relevant_market_cap = get_relevant_market_cap(relevant_crypto_assets)
  if x = relevant_crypto_assets.find { |x| x['symbol'] == symbol}
    precice_allocation_percentage = x['quote']['USD']['market_cap'] / relevant_market_cap
  else
  end
end

def get_precise_allocation_usdc(precise_allocation_percentage)
  return precise_allocation_percentage * USDC_AMOUNT
end

def append_precise_allocations_to_relevant_crypto_assets(relevant_crypto_assets)
  relevant_crypto_assets_with_precise_allocations = []
  relevant_crypto_assets.each do |relevant_crypto_asset|
    precise_allocation_percentage = get_precise_allocation_percentage(relevant_crypto_assets,relevant_crypto_asset['symbol'])
    precise_allocation_usdc = get_precise_allocation_usdc(precise_allocation_percentage)
    relevant_crypto_asset['precise_allocation_percentage'] = precise_allocation_percentage
    relevant_crypto_asset['precise_allocation_usdc'] = precise_allocation_usdc
    relevant_crypto_assets_with_precise_allocations << relevant_crypto_asset
  end
  return relevant_crypto_assets_with_precise_allocations
end

def append_preferred_quote_asset_and_trading_pair_to_relevant_crypto_assets(relevant_crypto_assets,binance_crypto_assets)
  relevant_crypto_assets_with_preferred_quote_assets_and_trading_pair = []
  relevant_crypto_assets.each do |relevant_crypto_asset|
    aligned_symbol = get_aligned_crypto_asset_symbol(relevant_crypto_asset['symbol'])

    if aligned_symbol == 'BTC' || aligned_symbol == 'ETH'
      preferred_quote_asset = 'USDC'
    else
      if x = binance_crypto_assets['symbols'].find { |x| x['quoteAsset'] == 'ETH' && x['baseAsset'] == aligned_symbol && x['status'] == 'TRADING'}
        preferred_quote_asset = 'ETH'
      else
        if x = binance_crypto_assets['symbols'].find { |x| x['quoteAsset'] == 'BTC' && x['baseAsset'] == aligned_symbol && x['status'] == 'TRADING'}
          preferred_quote_asset = 'BTC'
        else
          if x = get_binance_crypto_assets['symbols'].find { |x| x['quoteAsset'] == aligned_symbol && x['baseAsset'] == 'USDC' && x['status'] == 'TRADING'}
            preferred_quote_asset = 'USDC'
          else
            preferred_quote_asset = 'NA'
          end
        end
      end
    end

    relevant_crypto_asset['preferred_quote_asset'] = preferred_quote_asset
    relevant_crypto_asset['trading_pair'] = [aligned_symbol,preferred_quote_asset].join()

    relevant_crypto_assets_with_preferred_quote_assets_and_trading_pair << relevant_crypto_asset
  end
  return relevant_crypto_assets_with_preferred_quote_assets_and_trading_pair
end

def append_filters_to_relevant_crypto_assets(relevant_crypto_assets,binance_crypto_assets)
  relevant_crypto_assets_with_filters = []
  relevant_crypto_assets.each do |relevant_crypto_asset|
    aligned_symbol = get_aligned_crypto_asset_symbol(relevant_crypto_asset['symbol'])
    if x = binance_crypto_assets['symbols'].find { |x| x['symbol'] == relevant_crypto_asset['trading_pair']}
      if y = x['filters'].find { |y| y['filterType'] == "MIN_NOTIONAL"}
        min_notional = y['minNotional'].to_f
      end
      if y = x['filters'].find { |y| y['filterType'] == "LOT_SIZE"}
        min_quantity = y['minQty'].to_f
        max_quantity = y['maxQty'].to_f
        step_size = y['stepSize'].to_f
      end
      if y = x['filters'].find { |y| y['filterType'] == "PRICE_FILTER"}
        min_price = y['minPrice'].to_f
        max_price = y['maxPrice'].to_f
      end
    end
    filters = {
      'min_notional' => min_notional,
      'min_quantity' => min_quantity,
      'max_quantity' => max_quantity,
      'step_size' => step_size,
      'min_price' => min_price,
      'max_price' => max_price
    }
    relevant_crypto_asset['filters'] = filters
    relevant_crypto_assets_with_filters << relevant_crypto_asset
  end
  return relevant_crypto_assets_with_filters
end

def append_trading_pair_price_to_relevant_crypto_assets(relevant_crypto_assets)
  relevant_crypto_assets_with_trading_pair_prices = []
  relevant_crypto_assets.each do |relevant_crypto_asset|
    aligned_symbol = get_aligned_crypto_asset_symbol(relevant_crypto_asset['symbol'])
    preferred_quote_asset = relevant_crypto_asset['preferred_quote_asset']
    trading_pair_price = get_binance_pair_price(aligned_symbol,preferred_quote_asset)
    relevant_crypto_asset['trading_pair_price'] = trading_pair_price
    relevant_crypto_assets_with_trading_pair_prices << relevant_crypto_asset
  end
  return relevant_crypto_assets_with_trading_pair_prices
end

def remove_blacklisted_crypto_assets_from_coinmarketcap_crypto_assets(coinmarketcap_crypto_assets)
  cmc_assets_without_blacklisted_crypto_assets = []
  coinmarketcap_crypto_assets.each do |coinmarketcap_crypto_asset|
    if BLACKLISTED_CRYPTO_ASSETS.include? coinmarketcap_crypto_asset['symbol']
    else
      cmc_assets_without_blacklisted_crypto_assets << coinmarketcap_crypto_asset
    end
  end
  return cmc_assets_without_blacklisted_crypto_assets
end

def generate_overview(coinmarketcap_crypto_assets,binance_crypto_assets)
  cmc_assets_without_blacklisted_crypto_assets = remove_blacklisted_crypto_assets_from_coinmarketcap_crypto_assets(coinmarketcap_crypto_assets)
  relevant_crypto_assets = get_relevant_crypto_assets(cmc_assets_without_blacklisted_crypto_assets,binance_crypto_assets)
  overview = {
    'usdc_amount' => USDC_AMOUNT,
    'limit' => LIMIT,
    'crypto_asset_type' => TYPE,
    'market_coverage' => (get_relevant_market_cap(relevant_crypto_assets) / get_total_market_cap(coinmarketcap_crypto_assets)).round(4),
    'blacklisted_crypto_assets' => BLACKLISTED_CRYPTO_ASSETS
  }
  return overview
end

def generate_relevant_crypto_assets(coinmarketcap_crypto_assets,binance_crypto_assets)
  cmc_assets_without_blacklisted_crypto_assets = remove_blacklisted_crypto_assets_from_coinmarketcap_crypto_assets(coinmarketcap_crypto_assets)
  relevant_crypto_assets = get_relevant_crypto_assets(cmc_assets_without_blacklisted_crypto_assets,binance_crypto_assets)
  relevant_crypto_assets = append_precise_allocations_to_relevant_crypto_assets(relevant_crypto_assets)
  relevant_crypto_assets = append_preferred_quote_asset_and_trading_pair_to_relevant_crypto_assets(relevant_crypto_assets,binance_crypto_assets)
  relevant_crypto_assets = append_filters_to_relevant_crypto_assets(relevant_crypto_assets,binance_crypto_assets)
  relevant_crypto_assets = append_trading_pair_price_to_relevant_crypto_assets(relevant_crypto_assets)
  relevant_crypto_assets = append_usdc_price_to_relevant_crypto_assets(relevant_crypto_assets)
  return relevant_crypto_assets
end

def generate_decreasing_percentages()
  decreasing_percentages = []
  numbers = [*0..100].reverse
  numbers.each do |number|
    decreasing_percentages << (number.to_f / 100.to_f).to_f
  end
  return decreasing_percentages
end

def generate_even_allocation_percentage(relevant_crypto_assets)
  return (1.to_f / relevant_crypto_assets.count.to_f).to_f
end

def crypto_asset_passes_filters?(relevant_crypto_asset,even_allocation_percentage,equalizer_percentage)
  min_notional = relevant_crypto_asset['filters']['min_notional']
  min_quantity = relevant_crypto_asset['filters']['min_quantity']
  max_quantity = relevant_crypto_asset['filters']['max_quantity']
  step_size = relevant_crypto_asset['filters']['step_size']

  equalizer_delta = relevant_crypto_asset['precise_allocation_percentage'] - even_allocation_percentage
  adjusted_allocation_percentage = even_allocation_percentage + equalizer_delta * equalizer_percentage
  adjusted_allocation_usdc = (adjusted_allocation_percentage * USDC_AMOUNT)
  adjusted_quantity = (adjusted_allocation_usdc / relevant_crypto_asset['usdc_price'])

  max_decimal_places_count = count_decimal_places(step_size)

  if relevant_crypto_asset['symbol'] == 'BTC'
    quantity_rounded_down_by_step_size = adjusted_quantity
  else
    quantity_rounded_down_by_step_size = adjusted_quantity.floor2(max_decimal_places_count)
  end

  quantity_of_quote_asset = quantity_rounded_down_by_step_size * relevant_crypto_asset['trading_pair_price']

  if quantity_of_quote_asset >= min_notional && quantity_rounded_down_by_step_size >= min_quantity && quantity_rounded_down_by_step_size <= max_quantity
    return true
  else
    return false
  end
end

def append_usdc_price_to_relevant_crypto_assets(relevant_crypto_assets)
  relevant_crypto_assets_with_usdc_price = []
  relevant_crypto_assets.each do |relevant_crypto_asset|
    usdc_price = calculate_usdc_price(relevant_crypto_asset['symbol'],relevant_crypto_asset['preferred_quote_asset'],relevant_crypto_asset['trading_pair_price'])
    relevant_crypto_asset['usdc_price'] = usdc_price
    relevant_crypto_assets_with_usdc_price << relevant_crypto_asset
  end
  return relevant_crypto_assets_with_usdc_price
end

def calculate_usdc_price(base_asset_symbol,quote_asset_symbol,trading_pair_price)
  if base_asset_symbol == 'BTC'
    return BTC_USDC_PRICE
  elsif base_asset_symbol == 'ETH'
    return ETH_USDC_PRICE
  else
    if quote_asset_symbol == 'ETH'
      return ETH_USDC_PRICE * trading_pair_price
    else
      return BTC_USDC_PRICE * trading_pair_price
    end
  end
end

def calculate_maximum_equalizer_percentage(relevant_crypto_assets)
  viable_percentages = []
  even_allocation_percentage = generate_even_allocation_percentage(relevant_crypto_assets)
  decreasing_percentages = generate_decreasing_percentages()
  relevant_crypto_assets.each do |relevant_crypto_asset|
    decreasing_percentages.each do |equalizer_percentage|
      if crypto_asset_passes_filters?(relevant_crypto_asset,even_allocation_percentage,equalizer_percentage) == true
        viable_percentages << equalizer_percentage
        break
      elsif crypto_asset_passes_filters?(relevant_crypto_asset,even_allocation_percentage,equalizer_percentage) == false && equalizer_percentage == 0
        return "Insufficient Funds"
      else
      end
    end
  end
  return viable_percentages.min - BUFFER
end

def generate_allocations(relevant_crypto_assets)
  trading_actions_array = []
  maximum_equalizer_percentage = calculate_maximum_equalizer_percentage(relevant_crypto_assets)
  if maximum_equalizer_percentage == "Insufficient Funds"
    return '{ "insufficient_funds": true }'
  end
  even_allocation_percentage = generate_even_allocation_percentage(relevant_crypto_assets)
  relevant_crypto_assets.each do |relevant_crypto_asset|
    step_size = relevant_crypto_asset['filters']['step_size']
    equalizer_delta = relevant_crypto_asset['precise_allocation_percentage'] - even_allocation_percentage
    adjusted_allocation_percentage = even_allocation_percentage + equalizer_delta * maximum_equalizer_percentage
    adjusted_allocation_usdc = (adjusted_allocation_percentage * USDC_AMOUNT)
    adjusted_quantity = (adjusted_allocation_usdc / relevant_crypto_asset['usdc_price'])
    max_decimal_places_count = count_decimal_places(step_size)
    quantity_rounded_down_by_step_size = adjusted_quantity.floor2(max_decimal_places_count)
    quantity_of_quote_asset = quantity_rounded_down_by_step_size * relevant_crypto_asset['trading_pair_price']

    trading_actions = {
      'symbol' => relevant_crypto_asset['symbol'],
      'usdc_price' => relevant_crypto_asset['usdc_price'],
      'precise_allocation_percentage' => relevant_crypto_asset['precise_allocation_percentage'],
      'precise_allocation_usdc' => relevant_crypto_asset['precise_allocation_usdc'],
      'maximum_equalizer_percentage' => maximum_equalizer_percentage,
      'adjusted_allocation_percentage' => adjusted_allocation_percentage,
      'adjusted_allocation_usdc' => adjusted_allocation_usdc,
      'quantity_rounded_down_by_step_size' => quantity_rounded_down_by_step_size,
      'preferred_quote_asset' => relevant_crypto_asset['preferred_quote_asset'],
      'quantity_of_quote_asset' => quantity_of_quote_asset,
      'step_size' => step_size,
      'cmc_id' => relevant_crypto_asset['id'],
      'cmc_order_pair_symbol' => [get_aligned_crypto_asset_symbol(relevant_crypto_asset['symbol']),relevant_crypto_asset['preferred_quote_asset']].join('')
    }

    trading_actions_array << trading_actions

  end
  return trading_actions_array
end

def generate_overview_allocations_and_orders(overview,allocations,orders)
  overview_allocations_and_orders = {
    'overview' => overview,
    'allocations' => allocations,
    'orders' => orders
  }
  return overview_allocations_and_orders
end

def generate_orders(allocations)
  orders = []
  array_of_required_btc = []
  array_of_required_eth = []
  allocations.each do |allocation|
    if allocation['preferred_quote_asset'] == 'BTC'
      array_of_required_btc << allocation['quantity_of_quote_asset']
    elsif allocation['preferred_quote_asset'] == 'ETH'
      array_of_required_eth << allocation['quantity_of_quote_asset']
    else
    end
  end

  eth_usdc = allocations.find { |eth_usdc| eth_usdc['symbol'] == 'ETH'}

  order = {
    'symbol' => 'ETHUSDC',
    'quantity' => (array_of_required_eth.inject(:+) + eth_usdc['quantity_rounded_down_by_step_size']).ceil2(5)
  }
  orders << order

  btc_usdc = allocations.find { |btc_usdc| btc_usdc['symbol'] == 'BTC'}

  order = {
    'symbol' => 'BTCUSDC',
    'quantity' => (array_of_required_btc.inject(:+) + btc_usdc['quantity_rounded_down_by_step_size']).ceil2(6)
  }
  orders << order

  allocations.each do |allocation|
    aligned_symbol = get_aligned_crypto_asset_symbol(allocation['symbol'])
    order = {
      'symbol' => [aligned_symbol,allocation['preferred_quote_asset']].join(),
      'quantity' => allocation['quantity_rounded_down_by_step_size']
    }
    if order['symbol'] != 'ETHUSDC' && order['symbol'] != 'BTCUSDC'
      orders << order
    end
  end
  return orders
end

def conduct_orders(overview_allocations_and_orders,order_env)
  client = Binance::Client::REST.new api_key: BINANCE_API_KEY, secret_key: BINANCE_API_SECRET
  overview_allocations_and_orders['orders'].each do |order|
    if order_env == 'production'
      place_order = client.create_order! symbol: order['symbol'], side: 'BUY', type: 'MARKET', quantity: order['quantity']
    else
      place_order = client.create_test_order symbol: order['symbol'], side: 'BUY', type: 'MARKET', quantity: order['quantity']
    end
    puts place_order
    puts order
  end
end
