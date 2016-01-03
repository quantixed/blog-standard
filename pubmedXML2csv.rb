#!/usr/bin/ruby
 
require 'nokogiri'
 
f = File.open(ARGV.first)
doc = Nokogiri::XML(f)
f.close
 
doc.xpath("//PubmedArticle").each do |a|
  r = ["", "", "", ""]
  r[0] = a.xpath("MedlineCitation/Article/Journal/ISOAbbreviation").text
  r[1] = a.xpath("MedlineCitation/PMID").text
  r[2] = a.xpath("MedlineCitation/Article/ELocationID [@EIdType='doi']").text
  r[3] = a.xpath("MedlineCitation/Article/PublicationTypeList/PublicationType").text
  puts r.join(",")
end
