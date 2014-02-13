require 'rubygems'
require 'mechanize'
require 'nokogiri'
require 'csv'
require 'json'

@agent = Mechanize.new
@agent.get "http://www.bucme.hkbu.edu.hk"

@cookies = []
File.open("chrome_cookies.txt", 'r') do |f|
  columns = [:name, :value, :domain, :path, :u1, :u2]
  current_column = 0
  current_data = {}
  f.each_line do |l|
    if current_column >= columns.count
      @cookies << current_data
      current_data = {}
      current_column = 0
    end

    current_data[columns[current_column]] = l.strip
    current_column += 1
  end
end

@cookies.each do |data|
  cookie = Mechanize::Cookie.new(data[:name], data[:value])
  cookie.domain = data[:domain]
  cookie.path = data[:path]
  @agent.cookie_jar.add(@agent.history.last.uri, cookie)
end

@agent.get "https://www.bucme.hkbu.edu.hk/student/main.php"

#Student Helper Job
page = @agent.page.link_with(text: "Student Helper Job").click
doc = Nokogiri.HTML(page.body, "UTF-8")
CSV.open("helper_jobs.csv", "w") do |csv|
  table = doc.css("table#helper_job_table")
  
  #Header
  headers = []
  table.xpath("//table//thead//tr//td").each do |row|
    headers << row.text.strip
  end
  csv << headers
  
  #Content
  table.xpath("//table//tbody//tr").each do |row|
    content = []
    row.xpath("td").each do |column|
      content << column.text.strip
    end
    csv << content
  end
end

#Current Openings
CSV.open("current_jobs.csv", "w") do |csv|
  #Header
  page = @agent.page.link_with(text: "Current Openings").click
  doc = Nokogiri.HTML(page.body, "UTF-8")
  table = doc.css("table#job_table")
  headers = []
  table.xpath("//table//thead//tr//th").each do |row|
    pp row
    headers << row.text.strip
  end
  headers[headers.count - 1] = "Link"
  csv << headers
  
  #Content
  page = @agent.post("https://www.bucme.hkbu.edu.hk/student/ajax_job_list.php")
  json = JSON.parse(page.body)
  page = @agent.post("https://www.bucme.hkbu.edu.hk/student/ajax_job_list.php", iDisplayLength:json["iTotalRecords"].to_i)
  json = JSON.parse(page.body)
  
  json["aaData"].each do |data|
    data_doc = Nokogiri.HTML(data[1])
    data[1] = data_doc.text
    data[data.count-1] = "https://www.bucme.hkbu.edu.hk/student/" + data_doc.css('a').attribute('href')
    csv << data
  end
end
