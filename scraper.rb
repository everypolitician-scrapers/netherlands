# #!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'open-uri/cached'
require 'date'

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

def get_name_parts(tds)
  sort_name = tds[0].css('a').text
  name_parts = tds[0].css('a').text.split(',')
  first_name = tds[1].css('span').text
  last_name = name_parts.first
  middle_names = name_parts.last.split('.').drop(1)
  middle_name = middle_names.join(' ')
  name = [first_name, middle_name, last_name].join(' ')
  name = name.strip.gsub(/\s+/, " ")

  return {
    name: name,
    sort_name: sort_name,
    family_name: last_name,
    given_name: first_name,
  }
end

def scrape_list(url, base_url)
  noko = noko_for(url)
  noko.css('table.member-list tbody tr').each do |tr|
    tds = tr.css('td')
    next if tds.size == 1

    name_parts = get_name_parts(tds)

    faction_id = tds[2].css('span').text
    faction = expand_party(faction_id)

    data_rel = tds[0].css('a/@data-rel').text
    extra_div = noko.css('div.' + data_rel )

    img = extra_div.css('img/@src').text

    extra_url = URI.join(base_url, extra_div.css('a/@href').text.to_s)
    extra_data = get_extra_data(extra_url)

    data = {
      id: extra_url.to_s.split('/').last,
      name: name_parts[:name],
      family_name: name_parts[:family_name],
      given_name: name_parts[:given_name],
      sort_name: name_parts[:sort_name],
      faction_id: faction_id,
      faction: faction,
      gender: tds[5].css('span').text.downcase,
      img: URI.join(base_url, img.to_s).to_s,
      dob: extra_data[:dob],
      email: extra_data[:email],
      source: extra_url.to_s
    }
    ScraperWiki.save_sqlite([:id], data)
  end
end

def get_extra_data(url)
  noko = noko_for(url)
  email = noko.css('div.box-contact a').first.text
  details = noko.css('#passport dl')
  dob = details.xpath('//dl/dt[contains(.,"Date of birth")]/following-sibling::dd[not(position() > 1)]/text()')

  dob = Date.parse(dob.to_s)

  details = {
    email: email,
    dob: dob.to_s
  }

  return details
end

scrape_list('http://www.houseofrepresentatives.nl/members_of_parliament/members_of_parliament', 'http://www.houseofrepresentatives.nl')
