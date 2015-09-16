#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'colorize'
require 'pry'
require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
  end
end

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

def scrape_list(url)
  noko = noko_for(url)
  h2 = noko.xpath('//h2[span[@id="Election_results"]]')
  governates = h2.xpath('following-sibling::h2 | following-sibling::h3').slice_before { |e| e.name == 'h2' }.first
  governates.each do |governate|
    area = governate.css('span.mw-headline').text
    tables = governate.xpath('following-sibling::table | following-sibling::h3 | following-sibling::h2').slice_before { |e| e.name != 'table' }.first

    tables.each do |table|
      data = table.xpath('.//tr[td]').map do |tr|
        tds = tr.css('td')
        if area.include? 'Quota'
          { 
            name: tds[0].text.tidy,
            wikiname: tds[0].xpath('.//a[not(@class="new")]/@title').text,
            area: tds[3].text.tidy,
            party: tds[1].text.tidy,
            type: 'Woman',
          }
        elsif area == 'National List'
          tds[2].text.split(/,\s*/).map { |name|
            { 
              name: name,
              area: 'National List',
              type: 'National List',
              party: tds[0].text.tidy,
            }
          }
        else
          { 
            name: tds[0].text.tidy,
            wikiname: tds[0].xpath('.//a[not(@class="new")]/@title').text,
            area: area,
            party: tds[1].text.tidy,
            type: tds[2].text.tidy,
          }
        end
      end

      data.flatten.each do |p|
        entry = p.merge({ 
          term: '2013',
          source: url
        })
        ScraperWiki.save_sqlite([:name, :area, :type], entry)
      end

    end

  end
end

def scrape_person(url)
  noko = noko_for(url)
  binding.pry

# Members
  data = { 
    id: "%s-%s" % [name.downcase.gsub(/[[:space:]]+/,'-'), first_seen],
    name: name,
    party: tds[2].text.tidy,
    image: tds[1].css('img/@src').text,
    term: term[:id],
    notes: notes,
    source: url.to_s,
  }
  data[:image] = URI.join(url, data[:image]).to_s unless data[:image].to_s.empty?
  ScraperWiki.save_sqlite([:id, :term], data)
end

scrape_list('https://en.wikipedia.org/wiki/Jordanian_parliamentary_election_results,_2013')
