#!/usr/bin/env ruby

require 'yaml'
require 'json'
require 'csv'
require 'faraday'
require 'colorize'

@conf = YAML::load_file('config.yml')
#String.disable_colorization = true

api_key = ''
domain, *file_list = ARGV

conn = Faraday.new(url: "https://#{domain}.brickworksoftware.com") # create a new Connection with base URL
# puts conn.url_prefix

#String.color_samples

if domain =~ /staging$/i
  puts "STAGING".colorize(:cyan)
  api_key = @conf['bw_staging_api_key']
elsif domain =~ /uat$/i || domain =~ /qa$/i
  puts "UAT!".colorize(:yellow)
  sleep(5) # wait for paniked CTRL-C
  api_key = @conf['bw_uat_api_key']
else
  puts "PRODUCTION?!?".colorize(:red)
  sleep(5) # wait for paniked CTRL-C
  api_key = @conf['bw_prod_api_key']
end

errors = 0
lines = 0
file_list.each { |file|
  CSV.foreach(file) do |row|
    #puts row.to_json
    next if row[0].nil? || row[0].empty? # skip header line

    closed = ""
    if !row[5].nil? && !row[5].empty?
      closed = row[5].downcase == "yes" || row[5].downcase == "true"
    end

    hour = {
      "special_hour"=> {
        "date"=> row[1],
        "start_time"=> row[2],
        "end_time"=> row[3],
        "display_name"=> row[4],
        "closed"=> closed
      }
    }

    status = Array(2)
    color = :white
    if row[0] != "store_number" # don't submit header labels
      # puts JSON.pretty_generate(hour).colorize(:yellow)

      url = "/api/v3/admin/stores/#{row[0]}/special_hours.json"
      # puts url
      res = conn.post do |req|
        req.url url
        req.params['api_key'] = api_key
        req.params['store_number'] = "true"
        req.headers['Content-Type'] = 'application/json'
        req.body = hour.to_json
      end

      lines += 1

      # puts res.status
      # puts res.body

      if res.status.to_i >= 200 && res.status.to_i < 300 && res.body != 'An error has occurred'
        color = :green
        status = [ 'SUCCESS', '']
      else
        color = :red
        status = [ 'FAILURE', res.body]
        errors += 1
      end
    else
      color = :white
      status = ['result', 'error']
    end

    print (row[0,6] + status).to_csv.colorize(color)

  end
}

puts "\nLines Processed: #{lines}".colorize(:cyan)
puts "    Error Lines: #{errors}".colorize(errors > 0 ? :red : :green)
