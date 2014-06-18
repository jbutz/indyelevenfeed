ENV["RACK_ENV"] ||= "development"

require 'rubygems' unless defined?(Gem)
require 'bundler/setup'
require 'net/http'
Bundler.require(:default, ENV["RACK_ENV"].to_sym)
DEBUG = true

class IndyElevenFeed < Sinatra::Base
    get "/" do
        cache_control :max_age => 604800
        erb :index
    end

    get "/feed.xml" do
        cache_control :max_age => 86400

        uri = URI "http://www.indyeleven.com/matches/results"

        resp = Net::HTTP.get(uri)

        doc = Nokogiri::HTML.parse resp

        matchCollection = {}

        doc.css('tr.dayRow').each do |row|
            matchId = row.attr('data-matchid')
            matchDate = row.css('span.eventDateValue').first.text
            matchTime = row.css('span.eventTimeValue').first.text

            match = SoccerMatch.new(matchId, matchDate, matchTime)

            matchCollection[matchId] = match
        end

        doc.css('tr.dataRow').each do |row|

            matchId = row.attr('data-matchid')

            team1 = row.css('td.teamCol:first span').first.text
            team2 = row.css('td.teamCol:last span').first.text
            score = row.css('p.matchResultScore').first.text

            matchCollection[matchId].addTeamsScore(team1, team2, score)
        end

        entires = []

        matchCollection.each do |matchId, matchObj|
            entires << matchObj.getRssXml
        end

        erb(:atom_feed, {content_type: "text/xml; charset=UTF-8"},{entries: entires, updated: DateTime.now.rfc3339})
    end
end

class SoccerMatch
    attr_accessor :matchId, :matchDate, :matchTime, :team1, :team2, :score, :team1_score, :team2_score, :dateTime

    def initialize(matchId, matchDate, matchTime)
        @matchId = matchId
        @matchDate = matchDate
        @matchTime = matchTime

        tmpDateTime = DateTime._strptime "#{@matchDate} #{@matchTime}", "%m/%d/%y %I:%M %p"
        @dateTime = Time.local tmpDateTime[:year], tmpDateTime[:mon], tmpDateTime[:mday], tmpDateTime[:hour], tmpDateTime[:min]

    end

    def addTeamsScore(team1, team2, score)
        @team1 = team1
        @team2 = team2
        @score = score

        score = score.split ' - '

        @team1_score = score[0]
        @team2_score = score[1]
    end

    def findWinner
        if @team1_score > @team2_score
            return "#{@team1} beat #{@team2} #{@team1_score} - #{@team2_score}"
        elsif @team2_score > @team1_score
            return "#{@team2} beat #{@team1} #{@team2_score} - #{@team1_score}"
        else
            return "#{@team1} and #{@team2} tied #{@score}"
        end
    end

    def getRssXml

        {
            id: "http://www.indyeleven.com/matches/results##{@matchId}",
            title: "#{@team1} vs #{@team2}, #{@score}",
            summary: "#{@team1} vs #{@team2}, #{@score}",
            updated: @dateTime.to_datetime.rfc3339,
            author: "Indy Eleven",
            content: findWinner()
        }
        #"<entry>" +
        #"<id>#{@matchId}</id>" +
        #"<title>#{@team1} vs #{@team2}, #{@score}</title>" +
        #"<description>#{@team1} vs #{@team2}, #{@score}</description>" +
        #"<updated>#{@dateTime.rfc2822}</updated>" +
        #"</entry>"
    end
end
