# #!/bin/env ruby
# encoding: utf-8

require 'scraped'
require 'scraperwiki'

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

def scraper(h)
  url, klass = h.to_a.first
  klass.new(response: Scraped::Request.new(url: url).response)
end

def scrape_list(url)
  noko = noko_for(url)
  noko.css('table.member-list tbody tr').each_slice(2) do |tr, hidden|
    tds = tr.css('td')

    faction_id = tds[2].css('span').text
    faction = expand_party(faction_id)

    img = hidden.css('img/@src').text
    extra_url = URI.join(url, hidden.css('a.goto-member/@href').text)
    extra = scraper(extra_url => MemberPage).to_h

    data = {
      id: extra_url.to_s.split('/').last,
      name: hidden.css('h2').text,
      sort_name: tds[0].css('a').text,
      family_name: tds[0].css('a').text.split(',').first,
      given_name: tds[1].css('span').text,
      faction_id: faction_id,
      faction: faction,
      gender: tds[5].css('span').text.downcase,
      img: img.to_s.empty? ? '' : URI.join(url, img.to_s).to_s,
      source: extra_url.to_s
    }.merge(extra)

    puts data.reject { |_, v| v.to_s.empty? }.sort_by { |k, _| k }.to_h if ENV['MORPH_DEBUG']
    ScraperWiki.save_sqlite([:id], data)
  end
end

class String
  def to_date
    Date.parse(self).to_s rescue nil
  end
end

class MemberPage < Scraped::HTML
  field :email do
    contacts.first.text rescue nil
  end

  field :website do
    contacts[1].css('@href').to_s if contacts[1]
  end

  field :dob do
    noko.css('#passport dl').xpath('//dl/dt[contains(.,"Date of birth")]/following-sibling::dd[not(position() > 1)]/text()').to_s.to_date
  end

  private

  def contacts
    noko.css('div.box-contact a')
  end
end

ScraperWiki.sqliteexecute('DROP TABLE data') rescue nil
scrape_list('https://www.houseofrepresentatives.nl/members_of_parliament/members_of_parliament')
