class SpreadAnalyzer
  def initialize
    @bid_broker = nil
    @ask_broker = nil
    @best_bid = nil
    @best_ask = nil
    @best_amount = nil
  end

  def analyze(config)
    config[:brokers].each do |broker|
      analyze_price(broker)
    end

    spread = analyze_spread
    profit, profit_rate = analyze_profit(spread, config[:target_amount])
    return { bid_broker: @bid_broker, best_bid: @best_bid, ask_broker: @ask_broker, best_ask: @best_ask,
                          best_amount: @best_amount, spread: spread, profit: profit, profit_rate: profit_rate }
  end

  def analyze_price(broker)
    @bid_broker ||= broker[:broker]
    @best_bid ||= broker[:bid]
    @ask_broker ||= broker[:broker]
    @best_ask ||= broker[:ask]
    @best_amount = @best_amount.nil? && broker[:bid_amount] < broker[:ask_amount] ?
                                              broker[:bid_amount] : broker[:ask_amount]
    if @best_bid < broker[:bid]
      @bid_broker = broker[:broker]
      @best_bid = broker[:bid] 
      analyze_amount(broker[:bid_amount])
    end

    if @best_ask > broker[:ask]
      @ask_broker = broker[:broker]
      @best_ask = broker[:ask]
      analyze_amount(broker[:ask_amount])
    end
  end
  
  def analyze_amount(amount)
    @best_amount = amount if @best_amount < amount
  end

  def analyze_spread
    @best_bid - @best_ask
  end

  def analyze_profit(spread, amount)
    price = @best_ask * amount
    profit = (spread * amount).floor
    profit_rate = (100 * profit / price).floor(3)
    return  profit, profit_rate
  end
end