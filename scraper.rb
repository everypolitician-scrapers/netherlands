# #!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'date'

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

def name_parts(tds)
  sort_name = tds[0].css('a').text
  name_parts = tds[0].css('a').text.split(',')
  first_name = tds[1].css('span').text
  last_name = name_parts.first
  middle_names = name_parts.last.split('.').drop(1)
  middle_name = middle_names.join(' ')
  name = [first_name, middle_name, last_name].join(' ')
  name = name.strip.gsub(/\s+/, " ")

  return {
    # name: name,
    sort_name: sort_name,
    family_name: last_name,
    given_name: first_name,
  }
end

def scrape_list(url)
  noko = noko_for(url)
  noko.css('table.member-list tbody tr').each_slice(2) do |tr, hidden|
    tds = tr.css('td')
    name = hidden.css('h2').text

    faction_id = tds[2].css('span').text
    faction = expand_party(faction_id)

    data_rel = tds[0].css('a/@data-rel').text
    extra_div = noko.css('div.' + data_rel )

    img = extra_div.css('img/@src').text

    extra_url = URI.join(url, extra_div.css('a/@href').text.to_s)

    data = {
      id: extra_url.to_s.split('/').last,
      name: name,
      faction_id: faction_id,
      faction: faction,
      gender: tds[5].css('span').text.downcase,
      img: img.to_s.empty? ? '' : URI.join(url, img.to_s).to_s,
      source: extra_url.to_s
    }.merge(name_parts(tds)).merge(extra_data(extra_url))

    puts data.reject { |_, v| v.to_s.empty? }.sort_by { |k, _| k }.to_h if ENV['MORPH_DEBUG']

    ScraperWiki.save_sqlite([:id], data)
  end
end

def extra_data(url)
  noko = noko_for(url)
  contacts = noko.css('div.box-contact a')
  email = contacts.first.text rescue nil
  website = contacts[1].css('@href').to_s if contacts[1]
  details = noko.css('#passport dl')
  dob = details.xpath('//dl/dt[contains(.,"Date of birth")]/following-sibling::dd[not(position() > 1)]/text()')

  dob = Date.parse(dob.to_s)

  details = {
    email: email,
    dob: dob.to_s
  }

  details[:website] = website if website

  return details
end

ScraperWiki.sqliteexecute('DROP TABLE data') rescue nil
scrape_list('https://www.houseofrepresentatives.nl/members_of_parliament/members_of_parliament')
