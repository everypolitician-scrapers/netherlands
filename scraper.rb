# frozen_string_literal: true

# #!/bin/env ruby
# encoding: utf-8

require 'pry'
require 'scraped'
require 'scraperwiki'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class String
  def to_date
    Date.parse(self).to_s rescue nil
  end
end

class MembersPage < Scraped::HTML
  field :members do
    noko.css('table.member-list tbody tr').each_slice(2).map do |tr, hidden|
      fragment(tr => MemberRow).to_h.merge(fragment(hidden => MemberHiddenRow).to_h)
    end
  end
end

class MemberRow < Scraped::HTML
  field :sort_name do
    tds[0].css('a').text
  end

  field :family_name do
    tds[0].css('a').text.split(',').first
  end

  field :given_name do
    tds[1].css('span').text
  end

  field :faction_id do
    tds[2].css('span').text
  end

  field :faction do
    PARTIES.fetch(faction_id, faction_id)
  end

  field :gender do
    tds[5].css('span').text.downcase
  end

  private

  PARTIES = {
    'PVV'   => 'Party for Freedom',
    'VVD'   => "People's Party for Freedom and Democracy",
    'PvdA'  => 'Labour Party',
    'SP'    => 'Socialist Party',
    'D66'   => 'Democrats 66',
    'CU'    => 'Christian Union',
    'GL'    => 'Green Left',
    'SGP'   => 'Reformed Political Party',
    'PvdD'  => 'Party for the Animals',
    'GrKÖ'  => 'Group Kuzu/Öztürk',
    'GrBvK' => 'Bontes/Van Klaveren',
  }.freeze

  def tds
    noko.css('td')
  end
end

class MemberHiddenRow < Scraped::HTML
  field :id do
    source.to_s.split('/').last
  end

  field :name do
    noko.css('h2').text
  end

  field :img do
    img = noko.css('img/@src').text
    img.to_s.empty? ? '' : URI.join(url, img.to_s).to_s
  end

  field :source do
    URI.join(url, noko.css('a.goto-member/@href').text).to_s
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

def scraper(h)
  url, klass = h.to_a.first
  klass.new(response: Scraped::Request.new(url: url).response)
end

url = 'https://www.houseofrepresentatives.nl/members_of_parliament/members_of_parliament'
data = scraper(url => MembersPage).members.map do |mem|
  extra = scraper(mem[:source] => MemberPage).to_h
  mem.merge(extra)
end

data.each { |mem| puts mem.reject { |_, v| v.to_s.empty? }.sort_by { |k, _| k }.to_h } if ENV['MORPH_DEBUG']

ScraperWiki.sqliteexecute('DROP TABLE data') rescue nil
ScraperWiki.save_sqlite([:id], data)
