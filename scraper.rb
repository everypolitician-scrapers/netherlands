# #!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'open-uri/cached'

OpenURI::Cache.cache_path = '.cache'

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

def expand_party(party)
  parties = {
    'PVV' => 'Party for Freedom',
    'VVD' => "People's Party for Freedom and Democracy",
    'PvdA' => 'Labour Party',
    'SP' => 'Socialist Party',
    'D66' => 'Democrats 66',
    'CU' => 'Christian Union',
    'GL' => 'Green Left',
    'SGP' => 'Reformed Political Party',
    'PvdD' => 'Party for the Animals',
    'GrKÖ' => 'Group Kuzu/Öztürk',
    'GrBvK' => 'Bontes/Van Klaveren',
  }

  party = parties[party] if parties[party]

  return party
end

def scrape_list(url)
  noko = noko_for(url)
  noko.css('table.member-list tbody tr').each do |tr|
    tds = tr.css('td')
    next if tds.size == 1
    name_parts = tds[0].css('a').text.split(',')
    first_name = tds[1].css('span').text
    last_name = name_parts.first
    middle_names = name_parts.last.split('.').drop(1)
    middle_name = middle_names.join(' ')
    name = [first_name, middle_name, last_name].join(' ')
    name = name.strip.gsub(/\s+/, " ")
    faction = expand_party( tds[2].css('span').text )
    data_rel = tds[0].css('a/@data-rel').text
    img = noko.css('div.' + data_rel + ' img/@src').text
    data = {
      name: name,
      faction: faction,
      area: tds[3].css('span').text,
      gender: tds[5].css('span').text.downcase,
      img: 'http://www.houseofrepresentatives.nl' + img,
      source: url
    }
    ScraperWiki.save_sqlite([:name, :faction, :area], data)
  end
end

scrape_list('http://www.houseofrepresentatives.nl/members_of_parliament/members_of_parliament')
