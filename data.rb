module Api
  class Data
    require "net/http"
    require "json"
    require "terminal-table/import"
    require "yaml"
    attr_reader :access_key, :c_pair, :data

    def initialize(c_pair, timeframe, start_date, end_date)
      @access_key = "844826029804f6cad6d01d1f1a9f9c40-bad3ad61b02c6c2cc31459921a83a727"
      @c_pair = c_pair
      @timeframe = timeframe
      @start_date = format_date(start_date)
      @end_date = format_date(end_date)
      @data
      @results = []
      @prev_five = []
      @save_data = []
    end

    def api_call
      url = "https://api-fxtrade.oanda.com/v1/candles?instrument=#{@c_pair}&start=#{@start_date}&end=#{@end_date}&granularity=#{@timeframe}&dailyAlignment=0&candleFormat=midpoint&alignmentTimezone=America%2FChicago"

      uri = URI(url)

      response = Net::HTTP.get(uri)
      preData = JSON.parse(response)
      @data = preData["candles"]
    end

    def never_touch_open
      high = []
      low = []
      data.each_index do |i|
        low = data[i]["lowMid"]
        open = data[i]["openMid"]
        high = data[i]["highMid"]
        prev_open = data[i - 1]["openMid"]
        prev_low = data[i - 1]["lowMid"]
        prev_high = data[i - 1]["highMid"]
        if low >= prev_open && (high - open) / 2 > (open - prev_low)
          @results << data[i]
        end
        if high <= prev_open && (open - low) / 2 > (prev_high - open)
          @results << data[i]
        end
      end
      @data.each_index do |index|
        @results.each_index do |ind|
          p_five_push = []
          if @data[index]["time"] == @results[ind]["time"]
            (-5..-1).each do |num|
              p_five_push << @data[index + num]
            end
          end
          unless p_five_push == []
            @prev_five << p_five_push
          end
        end
      end
    end

    def c_prev_five
      @data.each_index do |i|
        p_five_push = []
        (-5..-1).each do |num|
          p_five_push << @data[i + num]
        end
        unless p_five_push == []
          @prev_five << p_five_push
        end
      end
    end

    def range
      @prev_five.each do |arr|
        highs = []
        lows = []
        date_range = ""
        arr.each_index do |i|
          highs << arr[i]["highMid"]
          lows << arr[i]["lowMid"]
          date_range = "#{arr[0]["time"]} - #{arr[4]["time"]}"
        end
        range = (highs.max - lows.min)
        arr.unshift(range)
      end
    end

    def movement
      range
      @prev_five.each do |arr|
        arr.each_index do |i|
          unless i == 0 || i == 1
            if (arr[i]["closeMid"] > arr[i - 1]["closeMid"])
              move = arr[i]["closeMid"] - arr[i - 1]["closeMid"]
              percentage = move / arr[0]
              arr[i]["Movement"] = "Up"
              arr[i]["Percent"] = percentage
            else
              move = arr[i]["closeMid"] - arr[i - 1]["closeMid"]
              percentage = move / arr[0]
              arr[i]["Movement"] = "Down"
              arr[i]["Percent"] = percentage
            end
          end
        end
      end
    end

    def print
      list = table do |t|
        t.title = "#{@c_pair} Candles"
        t.headings = "TIME", "OPEN", "HIGH", "LOW", "CLOSE", "VOLUME"
        @results.each do |candle|
          t << [candle["time"], candle["openMid"], candle["highMid"], candle["lowMid"], candle["closeMid"], candle["volume"]]
        end
      end
      puts list
    end

    def format_date(date)
      format_the_date = date
      format_the_date.insert(4, "-")
      format_the_date.insert(7, "-")
    end

    def save(file_name)
      to_save = []
      @prev_five.each do |arr|
        to_push = {}
        to_push["Range"] = arr[0]
        to_save << to_push
      end
      to_save.each do |obj|
        @prev_five.each do |arr|
          if obj["Range"] == arr[0]
            arr.each_index do |i|
              unless i == 0
                candle = {}
                candle["Movement"] = arr[i]["Movement"]
                candle["Percent"] = arr[i]["Percent"]
                obj[i] = candle
              end
            end
          end
        end
      end
      File.open("#{file_name}.yml", "w") do |file|
        file.write(to_save.to_yaml)
      end
    end
  end
end

data = Api::Data.new("USD_JPY", "H1", "20190201", "20190225")
data.api_call
data.never_touch_open
# data.print
data.movement
data.save("test_data")

c_data = Api::Data.new("USD_JPY", "H1", "20180101", "20180110")
c_data.api_call
c_data.c_prev_five
c_data.movement
c_data.save("compare_data")
