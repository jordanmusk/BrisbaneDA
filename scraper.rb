# Adapted from planningalerts.org.au to return data
# back to Jan 01, 2007

require 'scraperwiki'
require 'mechanize'
require 'date'

def scrape_page(page)
  page.at_xpath("//table").search("tr").each do |tr|
    begin
      tds = tr.search('td').map{|t| t.inner_text.gsub("\r\n", "").strip}
      day, month, year = tds[3].split("/").map{|s| s.to_i}
      record = {
        "info_url" => (page.uri + tr.search('td').at('a')["href"]).to_s,
        "council_reference" => tds[1].split(" - ")[0].squeeze(" ").strip,
        "date_received" => Date.new(year, month, day).to_s,
        "description" => tds[1].split(" - ")[1..-1].join(" - ").squeeze(" ").strip,
        "address" => tds[2].squeeze(" ").strip,
        "date_scraped" => Date.today.to_s
      }
      if (ScraperWiki.select("* from data where `council_reference`='#{record['council_reference']}'").empty? rescue true)
        ScraperWiki.save_sqlite(['council_reference'], record)
  #         else
  #           puts "Skipping already saved record " + record['council_reference']
      end
    rescue
      next
    end
  end
end


# Implement a click on a link that understands stupid asp.net doPostBack
def click(page, doc)
  begin
    js = doc["href"] || doc["onclick"]
    if js =~ /javascript:__doPostBack\('(.*)','(.*)'\)/
      event_target = $1
      event_argument = $2
      form = page.form_with(id: "aspnetForm")
      form["__EVENTTARGET"] = event_target
      form["__EVENTARGUMENT"] = event_argument
      form.submit
    elsif js =~ /return false;__doPostBack\('(.*)','(.*)'\)/
      nil
    else
      # TODO Just follow the link likes it's a normal link
      raise
    end
  rescue
    nil
  end
end

years = [2025, 2024, 2023, 2022, 2021, 2020]
periodstrs = years.map(&:to_s).product([*'-01'..'-12'].reverse).map(&:join).select{|d| d <= Date.today.to_s[0..-3]}.reverse

periodstrs.each {|periodstr| 

  matches = periodstr.scan(/^([0-9]{4})-(0[1-9]|1[0-2])$/)
  period = "&1=" + Date.new(matches[0][0].to_i, matches[0][1].to_i, 1).strftime("%d/%m/%Y")
  period = period + "&2=" + Date.new(matches[0][0].to_i, matches[0][1].to_i, -1).strftime("%d/%m/%Y")

  puts "Getting data in `" + periodstr + "`."

  url = "https://pdonline.brisbane.qld.gov.au/MasterViewUI/Modules/ApplicationMaster/default.aspx?page=found" + period

  agent = Mechanize.new

  # Read in a page
  page = agent.get(url)

  current_page_no = 1
  next_page_link = true

  while next_page_link
    if (current_page_no%5) == 0
      puts "Scraping page #{current_page_no}..."
    end
    scrape_page(page)

    current_page_no += 1
    next_page_link = page.at(".rgPageNext")
    page = click(page, next_page_link)
    next_page_link = nil if page.nil?
  end
  }
