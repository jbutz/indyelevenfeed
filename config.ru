require 'rubygems'
require 'bundler'
require 'uri'

Bundler.require

require File.expand_path(File.dirname(__FILE__) + '/app')

run IndyElevenFeed
