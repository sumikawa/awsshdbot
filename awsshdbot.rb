#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'user_stream'
require 'twitter'
require 'pp'
require 'net/http'
require 'json'
require 'nokogiri'
require 'optparse'
require 'yaml'

$options = {}
$options[:test] = false
OptionParser.new do |opts|
  opts.on("-t", "--test", "Test") do |v|
    $options[:test] = true
  end
end.parse!

twitconfig = YAML::load(File.open(File.join(File.dirname(__FILE__), '/config.yaml')))

if $options[:test] == false
  client = Twitter::REST::Client.new do |config|
    config.consumer_key        = twitconfig['consumer_key']
    config.consumer_secret     = twitconfig['consumer_secret']
    config.access_token        = twitconfig['oauth_token']
    config.access_token_secret = twitconfig['oauth_token_secret']
  end
end

current_desc = {}

loop do
  res = Net::HTTP.get_response(URI('http://status.aws.amazon.com/data.json'))
  sts = JSON.parse(res.body)

  if $options[:test] == true
    target = "archive"
  else
    target = "current"
  end

  sts[target].each do |i|
    desc = Nokogiri::HTML.parse(i["description"], nil, "UTF-8").xpath('/html/body/div[last()]').text
    if current_desc[i["service_name"]] != desc
      current_desc[i["service_name"]] = desc
#      date = Time.at(i["date"].to_i)
#      desc.sub!(/\d{1,2}:\d\d [AP]M P[SD]T/, "")
      mes = "#{i["service_name"]} - #{i["summary"]} - #{desc}"

      # make shorten
      mes.sub!(/^Amazon /, "")
      mes.gsub!(/  /, " ")
      mes.sub!(/^Elastic Compute Cloud/, "EC2")
      mes.sub!(/^Simple Email Service/, "SES")
      mes.sub!(/^Relational Database Service/, "RDS")
      mes.sub!(/^Elastic MapReduce/, "EMR")
      mes.sub!(/^Elastic Load Balancing/, "ELB")

      mes.scan(/.{,140} /).each do |word|
        if $options[:test] == true
          puts word
        else
          begin
            client.update word
          rescue Twitter::Error::AlreadyPosted => e
            # do nothing
          end
        end
      end
      puts "" if $options[:test] == true
    end
  end

  sleep 60
end
